require_relative 'repair/duplicate_leads'

module Repair
  def self.redis
    @redis ||= Redis.new
  end

  def self.each_active_campaign(account_ids=nil, &block)
    if account_ids.nil?
      Campaign.active.find_in_batches do |campaigns|
        campaigns.each do |campaign|
          yield campaign
        end
      end
    else
      Account.where(id: account_ids).each do |account|
        account.campaigns.active.each do |campaign|
          yield campaign
        end
      end
    end
  end

  def self.all_phone_numbers(campaign)
    dial_queue = campaign.dial_queue
    numbers = []
    numbers.concat dial_queue.available.all(:active)
    numbers.concat dial_queue.recycle_bin.all(:bin)
    numbers.concat dial_queue.completed.all(:completed)
    numbers.concat dial_queue.completed.all(:failed)
    numbers.concat dial_queue.blocked.all(:blocked)
    numbers
  end

end
