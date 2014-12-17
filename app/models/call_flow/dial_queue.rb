##
# Primary interface to manage read-only cache of queue/voter list data.
#
module CallFlow
  class DialQueue
    attr_reader :campaign
    delegate :next, to: :available
  private

    def load_if_nil(queue)
      send(queue) if queues[queue].nil?
    end

    def cache_household?(household)
      household.not_blocked? &&
      household.not_complete? &&
      available.missing?(household.phone) &&
      recycle_bin.missing?(household.phone)
    end

  public
    def self.enabled?
      (ENV['USE_REDIS_DIAL_QUEUE'] || '').to_i > 0
    end

    def self.next(campaign, n)
      new(campaign).next(n)
    end

    def self.dialed(household)
      dial_queue = new(household.campaign)
      dial_queue.dialed(household)
    end

    def self.remove(voter)
      dial_queue = new(voter.campaign)
      dial_queue.remove(voter)
    end

    def initialize(campaign)
      if campaign.nil? or campaign.id.nil?
        raise ArgumentError, "Campaign must not be nil and must have an id."
      end

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

    def not_dialed_count
      min = '-inf'
      max = '0.999'
      available.range_by_score(:active, min, max).size
    end

    def recycled_count
      min      = '1.0'
      max      = "#{Time.now.to_i}.999"
      available.range_by_score(:active, min, max).size
    end

    def cache(voter)
      household = voter.household
      unless cache_household?(household)
        p 'cache_household? => false'
        return 
      else
        # p 'cache_household? => true'
      end

      available.add(household) || recycle_bin.add(household)
      households.add(household.phone, voter.cache_data)
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
      p "dialed: #{household.phone}"
      unless recycle_bin.dialed(household)
        p "did not add to recycle bin"
        # phone number was not added to recycle bin
        # so will not be dialed again without admin action
        households.remove_house(household.phone)
      else
        p "added to recycle bin"
      end
      available.dialed(household.phone)
    end

    def remove_household(phone)
      available.remove(phone)
      recycle_bin.remove(phone)
      households.remove_house(phone)
    end

    def remove(voter)
      phone = voter.household.phone
      available.remove(phone)
      recycle_bin.remove(phone)
      households.remove_member(phone, voter)
    end

    def remove_all(voters)
      voters.each{|voter| remove(voter)}
    end

    def size(queue)
      send(queue).size
    end

    def peak(queue)
      send(queue).peak
    end

    def last(queue)
      send(queue).last
    end

    def clear(queue=nil)
      if queue.present?
        send(queue).clear
      else
        available.clear
        recycle_bin.clear
        households.clear
      end
    end
  end
end
