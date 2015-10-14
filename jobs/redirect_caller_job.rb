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
  extend SidekiqSelfQueue
  # Retries should occur in lower-level dependencies.
  # Sidekiq should not be used to retry it will almost certainly retry after
  # the call has ended.
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, location=:default)
    caller_session = CallerSession.find_by_id_cached(caller_session_id)

    if call_in_progress?(caller_session.sid)
      Providers::Phone::Call.redirect_for(caller_session, location)
      
    #  params = Providers::Phone::Call::Params::CallerSession.new(caller_session, location)
    #  call.redirect_to(params.url)
    else
      Rails.logger.error("RedirectCallerJob attempted to redirect Call[#{caller_session.sid}]")
    end
  end

  def call_in_progress?(sid)
    result = false
    Providers::Phone::Twilio.connect do |client|
      call   = client.calls.get(sid)
      result = call.status == 'in-progress'
    end
    return result
  end
end

