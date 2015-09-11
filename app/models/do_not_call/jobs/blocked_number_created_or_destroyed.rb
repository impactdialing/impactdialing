require 'librato_resque'

##
# Update all +Household+ records with `blocked: false` for a given account or campaign with a phone number matching the
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
class DoNotCall::Jobs::BlockedNumberCreatedOrDestroyed
  extend LibratoResque
  
  @queue = :dial_queue

  def self.perform(account_id, campaign_id, phone_number, integer)
    account    = Account.find account_id

    dial_queues_for(account, campaign_id).each do |dial_queue|
      dial_queue.update_blocked_property(phone_number, integer.to_i)
    end
  end

  def self.dial_queues_for(account, campaign_id)
    campaigns = campaign_id.blank? ? account.campaigns : account.campaigns.find(campaign_id)
    queues = [*campaigns].map do |campaign|
      CallFlow::DialQueue.new(campaign)
    end
  end
end

