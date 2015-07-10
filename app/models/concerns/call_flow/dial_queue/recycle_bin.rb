##
# Maintains cache of dialed or skipped phone numbers - really any number
# that has had some action taken by a caller or is otherwise
# not available for dialing right away.
#
class CallFlow::DialQueue::RecycleBin < CallFlow::DialQueue::PhoneNumberSet
public
  def keys
    {
      bin: "dial_queue:#{campaign.id}:bin"
    }
  end

  def add(household)
    redis.zadd keys[:bin], *memberize(household)

    return (not missing?(household.phone))
  end

  def reuse(&block)
    items = expired
    yield items
    remove_all items.map{|item| item.last}
  end

  def expired
    min   = '-inf'
    max   = "#{campaign.recycle_rate.hours.ago.to_i}.999"
    items = redis.zrangebyscore(keys[:bin], min, max, with_scores: true)

    # redis-rb returns [item, score] but expects [score, item] when pushing
    items.map{|item| item.rotate(1)}
  end

  def dialed(household)
    return false unless household.cache?
    add(household)
  end
end
