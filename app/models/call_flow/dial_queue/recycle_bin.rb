##
# Maintains cache of dialed or skipped phone numbers - really any number
# that has had some action taken by a caller or is otherwise
# not available for dialing right away.
#
class CallFlow::DialQueue::RecycleBin
  attr_reader :campaign

  delegate :recycle_rate, to: :campaign

  include CallFlow::DialQueue::Util
  include CallFlow::DialQueue::SortedSetScore

private
  def keys
    {
      bin: "dial_queue:#{campaign.id}:bin"
    }
  end

  def entries
    redis.zrange keys[:bin], 0, -1
  end

  def _benchmark
    @_benchmark ||= ImpactPlatform::Metrics::Benchmark.new("dial_queue.#{campaign.account_id}.#{campaign.id}.dialed")
  end

public
  def initialize(campaign)
    @campaign = campaign
  end

  def add(objects)
    expire keys[:bin] do
      redis.zadd keys[:bin], *memberize_collection(objects)
    end
  end

  def remove(object)
    redis.zrem keys[:bin], object.phone
  end

  def remove_all(phones)
    return if phones.blank?
    
    redis.zrem keys[:bin], phones
  end

  def size
    redis.zcard keys[:bin]
  end

  def all
    redis.zrange keys[:bin], 0, -1
  end

  def reuse(&block)
    items = expired
    yield items
    remove_all items.map{|item| item.last}
  end

  def expired
    min     = '-inf'
    max     = "#{campaign.recycle_rate.hours.ago.to_i}.999"
    items = redis.zrangebyscore(keys[:bin], min, max, with_scores: true)
    items.map{|item| item.rotate(1)}
  end
end
