##
# Primary interface to manage read-only cache of queue/voter list data.
#
module CallFlow
  class DialQueue
    attr_reader :campaign
    delegate :next, to: :available
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
      voter.not_called? or voter.call_back? or voter.retry?
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
  end
end
