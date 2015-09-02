##
# Primary interface to manage read-only cache of queue/voter list data.
#
module CallFlow
  class DialQueue
    attr_reader :campaign
    delegate :phone_key_index_stop, to: :households

    class EmptyHousehold < ArgumentError; end
    
  private
    def self.validate_campaign!(campaign)
      if campaign.nil? or campaign.id.nil? or campaign.account_id.nil? or (not campaign.respond_to?(:recycle_rate))
        raise ArgumentError, "Campaign must not be nil, must have an id, account_id & respond to :recycle_rate."
      end
    end

  public
    def self.log(type, msg)
      msg = "[CallFlow::DialQueue] #{msg}"
      Rails.logger.send(type, msg)
    end

    def log(type, msg)
      self.class.log(type, msg)
    end

    def initialize(campaign)
      self.class.validate_campaign!(campaign)

      @campaign = campaign
    end

    def available
      @available ||= CallFlow::DialQueue::Available.new(campaign)
    end

    def recycle_bin
      @recycle_bin ||= CallFlow::DialQueue::RecycleBin.new(campaign)
    end

    def households
      @households ||= CallFlow::DialQueue::Households.new(campaign)
    end

    def presented_households
      @presented_households ||= CallFlow::DialQueue::Households.new(campaign, :presented)
    end

    def completed
      @completed ||= CallFlow::DialQueue::Completed.new(campaign)
    end

    def blocked
      @blocked ||= CallFlow::DialQueue::Blocked.new(campaign)
    end

    def exists?
      available.exists? or recycle_bin.exists? or households.exists?
    end

    def next(n)
      phones = available.next(n)
      return nil if phones.empty?
      houses = households.find_presentable(phones)
      if houses.empty? and available.size > 0
        raise EmptyHousehold, "CallFlow::DialQueue#next(#{n}) found only empty households for #{phones}"
      end
      houses.each do |house|
        presented_households.save(house[:leads].first[:phone], house)
      end

      return houses
    end

    def recycle!
      recycle_bin.reuse do |expired|
        available.insert expired
      end
    end

    def dialed(household)
      unless recycle_bin.dialed(household)
        log :info, "Rejected by recycle bin. Removing Household[#{household.id}]"
        # phone number was not added to recycle bin
        # so will not be dialed again without admin action
        households.remove_house(household.phone)
      else
        log :info, "Not rejected by recycle bin. Keeping Household[#{household.id}]"
      end
      available.dialed(household.phone)
    end

    def dialed_number_persisted(phone, dispositioned_lead)
      add_to_recycle_bin = households.dial_again?(phone) ? 1 : 0
      Wolverine.dial_queue.dialed_number_persisted({
        keys: [available.keys[:presented], recycle_bin.keys[:bin], completed.keys[:completed]],
        argv: [phone, add_to_recycle_bin]
      })
      presented_households.remove_house(phone)
    end

    def failed!(phone)
      phone = PhoneNumber.sanitize(phone)
      update_presented_count = campaign.predictive? ? 1 : 0
      Wolverine.dial_queue.dial_failed({
        keys: [available.keys[:presented], completed.keys[:failed], Twillio::InflightStats.key(campaign)],
        argv: [phone, update_presented_count]
      })
    end

    def size(queue)
      send(queue).size
    end

    def last(queue)
      send(queue).last
    end

    def purge
      set_keys                 = []
      set_keys                += available.send(:keys).values
      set_keys                += recycle_bin.send(:keys).values
      household_prefix         = households.send(:keys)[:active]
      lua_phone_key_index_stop = phone_key_index_stop > 0 ? phone_key_index_stop + 1 : phone_key_index_stop
      purged_count             = 0

      campaign.timing("dial_queue.purge.time") do
        purged_count = Wolverine.dial_queue.purge(keys: set_keys, argv: [household_prefix, lua_phone_key_index_stop])
      end

      ImpactPlatform::Metrics.sample("dial_queue.purge.count", purged_count, campaign.metric_source.join('.'))

      return purged_count
    end
  end
end

