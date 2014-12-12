##
# Attempt to dial a +Household+ identified by given `phone` & `caller_session_id` and connect them to the
# +Caller+ of the +CallerSession+ identified by given `caller_session_id`.
# This job is queued from +Caller#calling_voter_preview_power+,
# +PhonesOnlyCallerSession#conference_started_phones_only_power+
# & +PhonesOnlyCallerSession#conference_started_phones_only_preview+.
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
class PreviewPowerDialJob
  include Sidekiq::Worker
  # Retries should occur in lower-level dependencies.
  # Sidekiq should not be used to retry it will almost certainly retry after
  # the call has ended.
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, phone)
    caller_session = CallerSession.find_by_id_cached(caller_session_id, includes: [:campaign])
    household      = caller_session.campaign.households.find_by_phone(phone)
    Twillio.dial(household, caller_session)
  end
end
