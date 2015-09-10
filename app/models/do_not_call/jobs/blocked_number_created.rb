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
  
  @queue = :dial_queue

  def self.perform(blocked_number_id)
    blocked_number = BlockedNumber.find blocked_number_id

    dial_queues = dial_queues_for(blocked_number)
    dial_queues.each do |dial_queue|
      # bitmask for :dnc block is 1; for :cell is 2; for both is 3
      dial_queue.update_blocked_property(blocked_number.number, 1)
    end
  end

  def self.dial_queues_for(blocked_number)
    campaigns = blocked_number.account_wide? ? blocked_number.account.campaigns : blocked_number.campaign
    queues = [*campaigns].map do |campaign|
      CallFlow::DialQueue.new(campaign)
    end
  end
end
