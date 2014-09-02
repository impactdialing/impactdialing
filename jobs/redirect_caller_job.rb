class RedirectCallerJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id)
    caller_session = CallerSession.find_by_id_cached(caller_session_id)
    # Providers::Phone::Call.redirect_for(caller_session)

    twilio = Twilio::REST::Client.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    call   = twilio.account.calls.get(caller_session.sid)
    params = Providers::Phone::Call::Params::CallerSession.new(caller_session)
    
    call.redirect_to(params.url)
  end
end