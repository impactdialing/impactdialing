class CallFlow::Call::Lead < CallFlow::Call
  attr_reader :caller_session_sid

  def self.namespace
    "lead"
  end

  def namespace
    self.class.namespace
  end

  def storage
    @storage ||= CallFlow::Call::Storage.new(account_sid, sid, namespace)
  end

  def caller_session_sid=(value)
    if value.present?
      @caller_session_sid = value
      storage.multi do
        storage[:caller_session_sid]   = value
        caller_session_call.dialed_call_sid = sid
      end
    end
  end

  def caller_session_sid
    @caller_session_sid ||= storage[:caller_session_sid]
  end

  def caller_session_call
    if caller_session_sid.present?
      CallFlow::CallerSession.new(account_sid, caller_session_sid)
    end
  end
end

