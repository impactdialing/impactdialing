module CallFlow
  class DialQueue
    attr_reader :campaign

    delegate :prepend, :seed, :refresh, :below_threshold?, :reload_if_below_threshold, to: :available
    delegate :household_dialed, to: :dialed

  private

    def load_if_nil(queue)
      send(queue) if queues[queue].nil?
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

    def self.household_dialed(campaign, phone, call_time)
      new(campaign).household_dialed(phone, call_time)
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

    def dialed
      @dialed ||= CallFlow::DialQueue::Dialed.new(campaign)
    end

    def next(n)
      queued_voters   = available.next(n)
      filtered_voters = dialed.filter(queued_voters)
      filtered_count  = queued_voters.size - filtered_voters.size

      if filtered_count > 0
        filtered_voters += self.next(filtered_count)
      end
      filtered_voters
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
