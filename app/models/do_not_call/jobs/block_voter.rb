require 'librato_resque'

##
# Update all +Voter+ records with `blocked: true` for a given account or campaign with a phone number matching the
# +BlockedNumber#number+ of the given `blocked_number_id`.
# This job is queued from after create in +BlockedNumber+.
#
# ### Metrics
#
# - failed
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
#
class DoNotCall::Jobs::BlockVoter
  extend LibratoResque
  
  @queue = :background_worker

  def self.perform(blocked_number_id)
    blocked_number = BlockedNumber.find blocked_number_id
    voters = voters_with(blocked_number)
    voters.enabled.update_all(enabled: Voter.bitmask_for_enabled(:list, :blocked))
    voters.disabled.update_all(enabled: Voter.bitmask_for_enabled(:blocked))
    Rails.logger.info "DoNotCall::Jobs::BlockVoter Account[#{blocked_number.account_id}] Campaign[#{blocked_number.campaign_id}] Number[#{blocked_number.number}] marked #{voters.count} voters blocked."
  end

  def self.voters_with(blocked_number)
    voters = if blocked_number.campaign_id.present?
               blocked_number.campaign.all_voters
             else
               blocked_number.account.voters
             end

    voters.where(phone: blocked_number.number)
  end
end
