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

    def cache_household?(household)
      household.cache? and
      available.missing?(household.phone) and
      recycle_bin.missing?(household.phone)
    end

    def cache_voter?(voter)
      voter.cache?
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

    def completed
      @completed ||= CallFlow::DialQueue::Completed.new(campaign)
    end

    def blocked
      @blocked ||= CallFlow::DialQueue::Blocked.new(campaign)
    end

    def exists?
      available.exists? or recycle_bin.exists? or households.exists?
    end

    def cache(voter)
      household = voter.household

      if cache_voter?(voter)
        households.add(household.phone, voter.cache_data)
      else
        remove(voter)
      end

      if cache_household?(household)
        available.add(household) or recycle_bin.add(household)
      end
    end

    def cache_all(voters)
      voters.each{|voter| cache(voter)}
    end

    def next(n)
      phones = available.next(n)
      return nil if phones.empty?
      houses = households.find_presentable(phones)
      if houses.empty? and available.size > 0
        raise EmptyHousehold, "CallFlow::DialQueue#next(#{n}) found only empty households for #{phones}"
      end
      return houses
    end

    def recycle!
      recycle_bin.reuse do |expired|
        available.insert expired
      end
    end

    # tell available & recycle bin of the dialed household
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

    def remove_household(phone)
      available.remove(phone)
      recycle_bin.remove(phone)
      households.remove_house(phone)
    end

    def remove(voter)
      phone             = voter.household.phone
      remaining_members = households.remove_member(phone, voter)
      if remaining_members.empty?
        available.remove(phone)
        recycle_bin.remove(phone)
      end
    end

    def remove_all(voters)
      voters.each{|voter| remove(voter)}
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
