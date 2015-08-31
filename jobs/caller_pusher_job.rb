##
# Trigger given Pusher `event` for +WebuiCallerSession+ with given `caller_session_id`.
# This job is queued for both +PhonesOnlyCallerSession+ & +WebuiCallerSession+.
# Pusher events are only triggered for +WebuiCallerSession+ instances with a
# +CallerSession#caller_type+ of 'Twilio client'.
#
# ### Metrics
#
# - completed count
# - failed count
#
# ### Monitoring
#
# Alert conditions:
# - 2 or more failures occur within 5 minutes
#
# todo: handle failure gracefully
class CallerPusherJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, event)
    caller_session = CallerSession.find(caller_session_id)

    source         = "ac-#{caller_session.campaign.account_id}.ca-#{caller_session.campaign.id}.cs-#{caller_session.id}"
    metrics        = ImpactPlatform::Metrics::JobStatus.started("#{self.class.to_s.underscore}.#{event}", source)

    begin
      caller_session.send(event)
    rescue CallFlow::DialQueue::EmptyHousehold => e
      # can be raised when event == publish_caller_conference_started
      Sidekiq::Client.push({
        'queue' => 'call_flow',
        'class' => CallerPusherJob,
        'args'  => [caller_session_id, event]
      })
      Rails.logger.error "#{e.class}: #{e.message}"
      name   = "#{event}.dial_queue.empty_household"
      ImpactPlatform::Metrics.count(name, 1, source)
    end
    
    metrics.completed
  end
end

