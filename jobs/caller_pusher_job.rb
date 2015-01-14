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
  # This job should only fail in exceptional circumstances. Retries should occur
  # in lower-level dependencies (ie `CallerSession#{trigger_event_method}`).
  # Sidekiq should not be used to retry it will almost certainly retry after
  # the relevant session has ended.
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, event)
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.class.to_s.underscore)
    
    caller_session = CallerSession.find(caller_session_id)

    begin
      caller_session.send(event)
    rescue CallFlow::DialQueue::Available::RedisTransactionAborted => e
      # can be raised when event == publish_caller_conference_started
      # which pops next number off the queue and sends it to the client
      Sidekiq::Client.push({
        'queue' => 'call_flow',
        'class' => CallerPusherJob,
        'args'  => [caller_session_id, event]
      })
      source = "ac-#{caller_session.campaign.account_id}.ca-#{caller_session.campaign.id}.cs-#{caller_session.id}"
      name   = "#{event}.dial_queue.available.redis_transaction_aborted"
      ImpactPlatform::Metrics.count(name, 1, source)
    end
    
    metrics.completed
  end
end
