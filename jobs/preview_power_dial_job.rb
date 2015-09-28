##
# Attempt to dial a +Household+ identified by given `phone` & `caller_session_id` and connect them to the
# +Caller+ of the +CallerSession+ identified by given `caller_session_id`.
# This job is queued from +PhonesOnlyCallerSession#conference_started_phones_only_power+
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
    caller_session = CallerSession.includes(:campaign).find_by_id(caller_session_id)
    unless already_dialed?(caller_session, phone)
      Twillio.dial(phone, caller_session)
    else
      source = [
        "ac-#{caller_session.campaign.account_id}",
        "ca-#{caller_session.campaign_id}",
        "cs-#{caller_session.id}",
        "dm-#{caller_session.campaign.type}"
      ].join('.')
      ImpactPlatform::Metrics.count('dialer.duplicate_dial', 1, source)
    end
  end

  def already_dialed?(caller_session, phone)
    caller_session.dialed_call.present? and caller_session.dialed_call.storage[:phone] == phone
  end
end
