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
  sidekiq_options :retry => false
  sidekiq_options :failures => true

   def perform(caller_session_id)
     caller_session = CallerSession.find(caller_session_id)
     Providers::Phone::Call.redirect_for(caller_session, :out_of_numbers)
   end
end