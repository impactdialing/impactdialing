## 
# Start playing a pre-recorded message to the dialed party.
# This job is queued when a caller clicks to drop a message to a dialed party.
#
# ### Metrics
#
# - failed count
#
# ### Monitoring
#
# Alert when 2 or more failures occur within 1 hour.
#
class Providers::Phone::Jobs::DropMessage
  include Sidekiq::Worker
  extend SidekiqSelfQueue
  # This job should only fail in exceptional circumstances. Retries should occur
  # in lower-level dependencies (ie `Providers::Phone::Call.play_message_for`).
  sidekiq_options :retry => false
  sidekiq_options :failures => true

public
  ##
  # When an error occurs making the request to drop the message, then we let the
  # caller know via voice redirect & pusher job.
  #
  def perform(caller_session_sid, call_sid)
    response = request_message_drop(call_sid)

    if response.error?
      caller_session = CallerSession.where(sid: caller_session_sid).first
      notify_client_of_error(caller_session, response)
      redirect_caller_to_error(caller_session)
    end
  end

private
  def request_message_drop(call_sid)
    Providers::Phone::Call.play_message_for(call_sid)
  end

  def redirect_caller_to_error(caller_session)
    Providers::Phone::Call.redirect_for(caller_session, :play_message_error)
  end

  def notify_client_of_error(caller_session, response)
    caller_session.publish_message_drop_error(I18n.t('dialer.message_drop.failed'), {
      response: response.response
    })
  end
end
