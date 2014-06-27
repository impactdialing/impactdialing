class Providers::Phone::Jobs::DropMessage
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

public
  def perform(call_id)
    @call = Call.includes(:call_attempt).find call_id

    response = request_message_drop

    if response.error?
      notify_client_of_error(response)
      redirect_caller_to_error
    end
  end

private
  def request_message_drop
    Providers::Phone::Call.play_message_for(@call)
  end

  def redirect_caller_to_error
    Providers::Phone::Call.redirect_for(@call.caller_session, :play_message_error)
  end

  def notify_client_of_error(response)
    @call.caller_session.publish_message_drop_error(I18n.t('dialer.message_drop.failed'), {
      response: response.response
    })
  end
end