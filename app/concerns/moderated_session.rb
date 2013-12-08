class ModeratedSession
  attr_reader :moderator, :caller_session, :type

  def self.switch_mode(moderator, caller_session, type)
    moderated_session = new(moderator, caller_session, type)
    moderated_session.update_caller_session
    moderated_session.toggle_mute

    return moderated_session.msg(:switch_mode)
  end

  def initialize(moderator, caller_session, type)
    @moderator      = moderator
    @caller_session = caller_session
    @type           = type
  end

  def toggle_mute
    mute = type != 'breakin'
    Providers::Phone::Conference.toggle_mute_for(conference_name, call_sid, {mute: mute})
  end

  def conference_name
    caller_session.session_key
  end

  def call_sid
    moderator.call_sid
  end

  def update_caller_session
    moderator.update_caller_session(caller_session.id)
  end

  def identity_name
    caller_session.caller.identity_name
  end

  def call_in_progress?
    return caller_session.voter_in_progress && (caller_session.voter_in_progress.call_attempts.last.status == "Call in progress")
  end

  def msg(method)
    msg = ''
    case method
    when :switch_mode
      msg = 'Status: '
      if call_in_progress?
        msg += "Monitoring in #{type} mode on #{identity_name}"
      else
        msg += 'Caller is not connected to a lead'
      end
    end
    return msg + '.'
  end
end