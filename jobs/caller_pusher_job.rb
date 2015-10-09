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
  extend SidekiqSelfQueue

  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def self.add_to_queue(caller_session, event, event_sequence=nil, payload={})
    if event_sequence.nil?
      call_flow_events = CallFlow::Events.new(caller_session.caller_session_call)
      event_sequence = call_flow_events.generate_sequence
    end

    Sidekiq::Client.push({
      'queue' => 'call_flow',
      'class' => CallerPusherJob,
      'args'  => [caller_session.id, event, event_sequence, payload]
    })
  end

  def perform(caller_session_id, event, event_sequence, payload={})
    caller_session   = CallerSession.find(caller_session_id)
    call_flow_events = CallFlow::Events.new(caller_session.caller_session_call)
    source           = [
      "ac-#{caller_session.campaign.account_id}",
      "ca-#{caller_session.campaign.id}",
      "cs-#{caller_session.id}"
    ].join('.')
    metric_name      = "#{self.class.to_s.underscore}.#{event}"
    metrics          = ImpactPlatform::Metrics::JobStatus.started(metric_name, source)

    if call_flow_events.completed?(event_sequence)
      name    = "call_flow.duplicate_job_run"
      source += ".seq-#{event_sequence}"
      ImpactPlatform::Metrics.count(name, 1, source)
      Rails.logger.error "[CallerPusherJob] Duplicate job run for CallerSession[#{caller_session.id}] EventSequence[#{event_sequence}] Event[#{event}]"
      return 
    end

    begin
      if payload.empty?
        caller_session.send(event)
      else
        caller_session.send(event, payload)
      end

      call_flow_events.completed(event_sequence)

    rescue CallFlow::DialQueue::InvalidHousehold => e
      # can be raised when event == publish_caller_conference_started
      self.class.add_to_queue(caller_session, event, event_sequence, payload)
      Rails.logger.error "[#{e.class}] #{e.message}"
      name   = "#{event}.dial_queue.#{e.class.to_s.split('::').last.underscore}"
      ImpactPlatform::Metrics.count(name, 1, source)
    end
    
    metrics.completed
  end
end

