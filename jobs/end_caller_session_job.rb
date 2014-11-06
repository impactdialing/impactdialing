##
# Clean-up calls & voters when a caller disconnects.
# This job is queued for +WebuiCallerSession+ & +PhonesOnlyCallerSession+.
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
# todo: make re-entrant/idempotent
# todo: stop updating voter statuses to 'not called'
#
class EndCallerSessionJob
  include Sidekiq::Worker
  # Eventually should be able to retry this. Current implementation would cause
  # data inconsistencies on retry as the CallAttempt.wrapup_calls sets all call
  # attempt records to have a wrapup_time of `Time.now`.
  sidekiq_options :retry => false
  sidekiq_options :failures => true

   def perform(caller_session_id)
     caller_session = CallerSession.find(caller_session_id)
     caller_id = caller_session.caller_id
     voter_ids = Voter.where(campaign_id: caller_session.caller.campaign_id, caller_id: caller_id, status: CallAttempt::Status::READY).pluck(:id)
     voter_ids.each_slice(100) do |list|
       Voter.where(id: list).update_all(status: 'not called')
     end
     CallAttempt.wrapup_calls(caller_id)
   end
end
