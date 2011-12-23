module MonitorsHelper
  
  def caller_status_and_duration(caller_session)
    call_attempt = caller_session.attempt_in_progress
    if call_attempt
      if call_attempt.status == (CallAttempt::Status::INPROGRESS || CallAttempt::Status::RINGING)
        status = "On call"
        duration = Time.now - call_attempt.created_at
      elsif call_attempt.wrapup_time.blank?
        status = "Wrap up"
        duration = Time.now - call_attempt.call_end
      else
        duration = Time.now - call_attempt.wrapup_time
        status = "On hold"
      end
    else
      status = "On hold"
      duration = Time.now - (caller_session.updated_at.nil? ? caller_session.created_at : caller_session.updated_at)
    end
    [status, Time.at(duration).gmtime.strftime('%R:%S')]
  end
  
  def caller_name(caller)
    caller.is_phones_only? ? caller.name : caller.email
  end
  
end