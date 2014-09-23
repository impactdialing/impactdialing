class CallFlow::DialQueue
  attr_reader :campaign, :queues

public
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

    @queues = {}
    @queues[:available] = CallFlow::DialQueue::Available.new(campaign)
  end

  def prepend(queue)
    queues[queue].prepend
  end

  def seed(queue)
    queues[queue].seed
  end

  def refresh(queue)
    queues[queue].refresh
  end

  def size(queue)
    queues[queue].size
  end

  def peak(queue)
    queues[queue].peak
  end

  def last(queue)
    queues[queue].last
  end

  def clear(queue)
    queues[queue].clear
  end

  def next(n)
    queues[:available].next(n)
  end

  def below_threshold?(queue)
    queues[queue].below_threshold?
  end

  def reload_if_below_threshold(queue)
    queues[queue].reload_if_below_threshold
  end
end
