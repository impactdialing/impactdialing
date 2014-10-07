module CallFlow
  class DialQueue
    attr_reader :campaign

    delegate :remove_household, :prepend, :seed, :refresh, :below_threshold?, :reload_if_below_threshold, to: :available
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

    def self.household_dialed(campaign, phone, call_time)
      dial_queue = new(campaign)
      dial_queue.household_dialed(phone, call_time)
      dial_queue.remove_household(phone)
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

    def next(n)
      queued_voters    = available.next(n)
      # filtered_voters  = dialed.filter(queued_voters)
      # print "\nDialQueue#next Attempted: #{n}; Got: #{filtered_voters.size}\n"
      # discarded_voters = queued_voters - filtered_voters
      # filtered_count   = discarded_voters.size

      # if filtered_voters.size > 0
      #   # queue job to clear recently dialed numbers & reload if needed
      # elsif filtered_voters.size.zero? and @_filter_loop_count <= 2
      #   filtered_voters += self.next(n)
      #   @_filter_loop_count += 1
      # end
      # if filtered_count > 0 and @_filter_loop_count <= self.class.filter_loop_limit
      #   ImpactPlatform::Metrics.count("dial_queue.#{campaign.account_id}.#{campaign.id}.filter_loop.count", 1)
      #   reload_if_below_threshold
      #   filtered_voters += self.next(filtered_count)
      #   @_filter_loop_count += 1
      # elsif @_filter_loop_count > self.class.filter_loop_limit
      #   ImpactPlatform::Metrics.count("dial_queue.#{campaign.account_id}.#{campaign.id}.filter_loop.limit_reached", 1)
      # end

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
