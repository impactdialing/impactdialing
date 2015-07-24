class CallFlow::Lead < CallFlow::Call
  attr_reader :caller_session_sid

  def storage
    @storage ||= CallFlow::Call::Storage.new(account_sid, sid, 'leads')
  end

  def caller_session_sid=(value)
    if value.present?
      @caller_session_sid = value
      storage.multi do
        storage[:caller_session_sid] = value
        caller_session.dialed_call   = sid
      end
    end
  end

  def caller_session_sid
    @caller_session_sid ||= storage[:caller_session_sid]
  end

  def caller_session
    if @caller_session_sid.present?
      CallFlow::CallerSession.new(account_sid, @caller_session_sid)
    end
  end
end
