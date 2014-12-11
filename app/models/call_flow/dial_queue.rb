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
      return false unless household.any_voters_to_dial?

      available.missing?(household.phone) &&
      recycle_bin.missing?(household.phone)
    end

  public
    def self.enabled?
      (ENV['USE_REDIS_DIAL_QUEUE'] || '').to_i > 0
    end

    def self.next(campaign, n)
      dial_queue  = CallFlow::DialQueue.new(campaign)
      next_voters = dial_queue.next(n)
      Voter.find next_voters.map{|voter| voter['id']}
    end

    def self.dialed(voter)
      dial_queue = new(voter.campaign)
      dial_queue.dialed(voter)
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

    def cache(voter)
      household = voter.household

      if cache_household?(household)
        available.add(household) || recycle_bin.add(household)
      end

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

    def next(n)
      phone_numbers      = available.next(n)
      current_households = households.find_all(phone_numbers)
      
      current_households.map{|phone, voters| voters.first}
    end

    def dialed(voter)
      recycle_bin.add(voter)
      # no need to rotate since web-ui caller will select
      # and system will auto-select for phones only callers
      # households.rotate(voter)
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
