##
# Tracks inflight call data for each caller session.
#
# Data lifetime:
# - starts: when caller establishes voice connection
# - pends persistence: when caller voice connection ends 
# - ends: when persisted to sql store
# - expires: in 24 hours (can be configured via ENV['CALL_FLOW_CALLER_SESSION_EXPIRY']
# 
# Impetus is to encapsulate & better define behaviors of CallerSession#attempt_in_progress.
#
class CallFlow::CallerSession < CallFlow::Call
protected
  def self.twiml_params(raw_params)
    parsed_params = super
    [:caller_id, :session_key].each do |param|
      if raw_params[param].present?
        parsed_params.merge!({param => raw_params[param]})
      end
    end
    parsed_params
  end

  def in_state?(state)
    RedisStatus.state_time(caller_session_record.campaign_id, caller_session_record.id).include?(state)
  end

public
  def self.namespace
    'caller_sessions'
  end

  def namespace
    self.class.namespace
  end

  def storage
    @storage ||= CallFlow::Call::Storage.new(account_sid, sid, namespace)
  end

  def dialed_call_sid=(value)
    if value.present?
      @dialed_call_sid = value
      storage[:dialed_call_sid] = value 
    end
  end

  def dialed_call_sid
    @dialed_call_sid ||= storage[:dialed_call_sid]
  end

  def dialed_call
    if dialed_call_sid.present?
      @dialed_call ||= CallFlow::Call::Dialed.new(account_sid, @dialed_call_sid)
    end
  end

  def skip_pause=(flag)
    storage[:skip_pause] = flag ? 1 : 0
  end

  def skip_pause?
    storage[:skip_pause].to_i > 0
  end

  def on_hold?
    in_state?('On hold')
  end

  def in_conversation?
    dialed_call.try(:in_progress?) and in_state?('On call')
  end

  def caller_session_record
    @caller_session_record ||= ::CallerSession.where(sid: sid).first
  end

  def is_phones_only?
    caller_session_record.is_phones_only?
  end

  def connect_to_lead(phone, call_sid)
    RedisStatus.set_state_changed_time(caller_session_record.campaign_id, "On call", caller_session_record.id)
    VoterConnectedPusherJob.add_to_queue(caller_session_record.id, call_sid, phone)
    self.dialed_call_sid = call_sid
  end

  def redirect_to_hold
    RedirectCallerJob.add_to_queue(caller_session_record.id)
    RedisStatus.set_state_changed_time(caller_session_record.campaign_id, "On hold", caller_session_record.id)
  end

  def stop_calling
    caller_session_record.end_caller_session
    EndRunningCallJob.add_to_queue(sid)
  end

  def emit(event, payload={})
    return if is_phones_only?
    CallerPusherJob.add_to_queue(caller_session_record, event, nil, payload)
  end
end

