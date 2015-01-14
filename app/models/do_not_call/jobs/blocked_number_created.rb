require 'librato_resque'

##
# Update all +Household+ records with `blocked: true` for a given account or campaign with a phone number matching the
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

    dial_queues = dial_queues_for(blocked_number)
    dial_queues.each{|dial_queue| dial_queue.remove_household(blocked_number.number)}

    Rails.logger.info "DoNotCall::Jobs::BlockedNumberCreated Account[#{blocked_number.account_id}] Campaign[#{blocked_number.campaign_id}] Number[#{blocked_number.number}] marked #{households.count} households blocked."
  end

  def self.dial_queues_for(blocked_number)
    campaigns = blocked_number.account_wide? ? blocked_number.account.campaigns : blocked_number.campaign
    queues = [*campaigns].map do |campaign|
      CallFlow::DialQueue.new(campaign)
    end
  end

  def self.households_with(blocked_number)
    households = unless blocked_number.account_wide?
                   blocked_number.campaign.households
                 else
                   blocked_number.account.households
                 end

    households.where(phone: blocked_number.number)
  end
end
