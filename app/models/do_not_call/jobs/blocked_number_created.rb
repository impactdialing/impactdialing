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
class DoNotCall::Jobs::BlockedNumberCreated
  extend LibratoResque
  
  @queue = :background_worker

  def self.perform(blocked_number_id)
    blocked_number = BlockedNumber.find blocked_number_id
    households = households_with(blocked_number)
    households.with_blocked(:cell).update_all(blocked: Household.bitmask_for_blocked(:dnc, :cell))
    households.without_blocked(:cell).update_all(blocked: Household.bitmask_for_blocked(:dnc))
    Rails.logger.info "DoNotCall::Jobs::BlockedNumberCreated Account[#{blocked_number.account_id}] Campaign[#{blocked_number.campaign_id}] Number[#{blocked_number.number}] marked #{households.count} households blocked."
  end

  def self.households_with(blocked_number)
    households = if blocked_number.campaign_id.present?
               blocked_number.campaign.households
             else
               blocked_number.account.households
             end

    households.where(phone: blocked_number.number)
  end
end
