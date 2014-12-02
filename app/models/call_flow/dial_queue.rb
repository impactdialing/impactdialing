##
# Primary interface to manage read-only cache of queue/voter list data.
#
module CallFlow
  class DialQueue
    attr_reader :campaign
  private

    def load_if_nil(queue)
      send(queue) if queues[queue].nil?
    end

    def cacheit?(voter)
      (voter.available_for_dial? || voter.can_eventually_be_retried?)
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
      return nil unless cacheit?(voter)

      unless voter.available_for_dial? && available.add(voter)
        recycle_bin.add(voter)
      end

      households.add(voter)
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
      if voter.can_eventually_be_retried?
        households.rotate(voter)
      else
        households.remove(voter)
      end
    end

    def remove(voter)
      available.remove(voter)
      recycle_bin.remove(voter)
      households.remove(voter)
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
