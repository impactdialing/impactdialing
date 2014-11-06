##
# Redirect a caller to new TwiML.
# This job is queued ... more than it should be.
# Currently queue this job whenever there is a change in a dialed call
# or the caller account has reached some error condition (eg out of funds).
#
# ### Metrics
#
# - failed count
#
# ### Monitoring
#
# Alert conditions:
#
# - 2 or more failures within 5 minutes
#
class RedirectCallerJob
  include Sidekiq::Worker
  # Retries should occur in lower-level dependencies.
  # Sidekiq should not be used to retry it will almost certainly retry after
  # the call has ended.
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id)
    caller_session = CallerSession.find_by_id_cached(caller_session_id)
    # Providers::Phone::Call.redirect_for(caller_session)

    twilio = Twilio::REST::Client.new(TWILIO_ACCOUNT, TWILIO_AUTH)
    call   = twilio.account.calls.get(caller_session.sid)

    if call.status == 'in-progress'
      params = Providers::Phone::Call::Params::CallerSession.new(caller_session)
      call.redirect_to(params.url)
    else
      Rails.logger.error("RedirectCallerJob attempted to redirect Call[#{call.sid}] Status[#{call.status}]")
    end
  end
end