class CallFlow::DialQueue
  attr_reader :campaign

  delegate :next, :prepend, :seed, :refresh, :below_threshold?, :reload_if_below_threshold, to: :available

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

  def initialize(campaign)
    if campaign.nil? or campaign.id.nil?
      raise ArgumentError, "Campaign must not be nil and must have an id."
    end

    @campaign = campaign
  end

  def available
    @available ||= CallFlow::DialQueue::Available.new(campaign)
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
