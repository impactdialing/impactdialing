module CallFlow
  class DialQueue
    attr_reader :campaign

    delegate :next, :remove_household, :seed, :refresh, :below_threshold?, :reload_if_below_threshold, to: :available
    delegate :household_dialed, to: :dialed

  private

    def load_if_nil(queue)
      send(queue) if queues[queue].nil?
    end

  public
    def self.enabled?
      (ENV['USE_REDIS_DIAL_QUEUE'] || '').to_i > 0
    end

    def self.filter_loop_limit
      (ENV['FILTER_LOOP_LIMIT'] || 15).to_i
    end

    def self.next(campaign, n)
      dial_queue  = CallFlow::DialQueue.new(campaign)
      next_voters = dial_queue.next(n)
      Voter.find next_voters.map{|voter| voter['id']}
    end

    def self.household_dialed(campaign, voter)
      dial_queue = new(campaign)
      dial_queue.household_dialed(voter)
    end

    def initialize(campaign)
      if campaign.nil? or campaign.id.nil?
        raise ArgumentError, "Campaign must not be nil and must have an id."
      end

      @campaign           = campaign
      @_filter_loop_count = 0
    end

    def available
      @available ||= CallFlow::DialQueue::Available.new(campaign, dialed)
    end

    def dialed
      @dialed ||= CallFlow::DialQueue::Dialed.new(campaign)
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

    def clear(queue)
      send(queue).clear
    end
  end
end
