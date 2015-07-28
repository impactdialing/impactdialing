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
    if @dialed_call_sid.present?
      @dialed_call ||= CallFlow::Call::Dialed.new(account_sid, @dialed_call_sid)
    end
  end
end

