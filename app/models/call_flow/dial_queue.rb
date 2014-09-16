class CallFlow::DialQueue
  attr_reader :campaign, :queues

public
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

  def size(queue)
    queues[queue].size
  end

  def peak(queue)
    queues[queue].peak
  end

  def clear(queue)
    queues[queue].clear
  end

  def next(n)
    queues[:available].next(n)
  end
end
