##
# Redirect a caller session to the 'campaign out of numbers' TwiML voice message.
# This job is queued from +CalculateDialsJob+ when there are no voters available to dial.
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
class CampaignOutOfNumbersJob
  include Sidekiq::Worker
  # Retries should occur in lower-level dependencies.
  # Sidekiq should not be used to retry it will almost certainly retry after
  # the call has ended.
  sidekiq_options retry: false, failures: true, queue: 'call_flow'

  def perform(caller_session_id)
    caller_session = CallerSession.find(caller_session_id)
    if caller_session.connected_to_lead?
      CampaignOutOfNumbersJob.perform_in(1.minute, caller_session_id)
    elsif caller_session.on_call?
      Providers::Phone::Call.redirect_for(caller_session, :out_of_numbers)
    end
  end
end
