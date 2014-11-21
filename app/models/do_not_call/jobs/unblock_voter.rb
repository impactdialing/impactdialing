require 'librato_resque'

##
# Update all +Voter+ records with `blocked: false` for a given account or campaign with a phone number matching the
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
class DoNotCall::Jobs::UnblockVoter
  extend LibratoResque
  
  @queue = :background_worker

  def self.perform(account_id, campaign_id, phone_number)
    voters = voters_with(account_id, campaign_id, phone_number)
    voters.enabled.update_all(enabled: Voter.bitmask_for_enabled(:list))
    voters.disabled.update_all(enabled: Voter.bitmask_for_enabled([]))
    Rails.logger.info "DoNotCall::Jobs::UnblockVoter Account[#{account_id}] Campaign[#{campaign_id}] Number[#{phone_number}] marked #{voters.count} voters unblocked."
  end

  def self.voters_with(account_id, campaign_id, phone_number)
    account = Account.find(account_id)
    voters  = if campaign_id.present?
               account.campaigns.find(campaign_id).all_voters
             else
               account.voters
             end

    voters.where(phone: phone_number)
  end
end
