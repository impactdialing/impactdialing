##
# Attempt to dial a +Voter+ identified by given `voter_id` and connect them to the
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

  def perform(caller_session_id, voter_id)
    caller_session = CallerSession.find_by_id_cached(caller_session_id)

    voter = Voter.find(voter_id)

    campaign = voter.campaign

    Rails.logger.error "JID-#{jid} RecycleRate PreviewPowerDialJob CallerSession[#{caller_session_id}] Voter[#{voter_id}] #{campaign.try(:type) || 'Campaign'}[#{campaign.try(:id)}]"

    if campaign.present? && campaign.within_recycle_rate?(voter)
      msg = "JID-#{jid} PreviewPowerDialJob - RecycleRateError:" +
            " CallerSession[#{caller_session.id}]" +
            " Voter[#{voter.id}] Campaign[#{campaign.id}]"
      Rails.logger.error msg
    end

    begin
      Twillio.dial(voter, caller_session)
      # if campaign.within_recycle_rate?(voter)
      #   # Twillio.dial(voter, caller_session)
      # else
      #   # tell the caller what happened
      #   # redirect the caller to trigger an update to the lead info
      #   # Providers::Phone::Call.redirect_for(caller_session, :voter_banned_by_recycle_rate)
      # end
    rescue ActiveRecord::StaleObjectError => e
      Providers::Phone::Call.redirect_for(caller_session)
      # rescue from any exception > tell the caller what happened > redirect
    end
  end
end
