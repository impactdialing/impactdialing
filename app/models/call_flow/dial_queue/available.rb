##
# Class for caching list of objects available for dialing right now.
# 
# Experiments show caching the id and phone as json list items for approx. 560,000 objects
# takes approx. 45-50KB. Extrapolating, I expect 100KB usage for ~1 million entries and
# ~100MB usage for ~1 billion entries.
#
# Based on the above numbers, there should be no issue with storing all available objects
# in the redis list for each campaign for the day. At the end of the calling hours for
# the campaign, the appropriate list should be removed.
#
# As a sorted set usage based on light experiments is approx. 0.61 MB for 5,000 numbers
# and ~155 MB for 717,978 numbers. Relative to current usage this number is ginormous.
#
# Configuring redis as follow reduces memory usage by ~50% to approx 0.14 MB for 5,000 numbers
# and ~77 MB for 717,978.
# - zset-max-ziplist-entries 6000
# - zset-max-ziplist-value 6000
# these may not be reasonable or even allowed by redislabs.
#
# Loading large data-sets requires good indexing.
#
# 
#
class CallFlow::DialQueue::Available
  attr_reader :campaign

  delegate :recycle_rate, to: :campaign

  include CallFlow::DialQueue::Util
  include CallFlow::DialQueue::SortedSetScore

  class RedisTransactionAborted < RuntimeError; end

private
  def keys
    {
      active: "dial_queue:#{campaign.id}:active",
      presented: "dial_queue:#{campaign.id}:presented"
    }
  end

  def zpoppush(n)
    n             = size if n > size
    retries       = 0
    phone_numbers = []

    # completed trxns return array ['OK'...]
    redis_result = redis.watch(keys[:active]) do
      members = redis.zrange keys[:active], 0, (n-1), with_scores: true
      
      return phone_numbers if members.empty?

      members.map(&:rotate!)
      phone_numbers = members.map(&:last)
      # update score so we can push these back to active if they're here too long
      presented     = members.map{|m| [Time.now.to_i, m[1]]}
      redis.multi do |multi|
        multi.zrem keys[:active], phone_numbers
        multi.zadd keys[:presented], presented
      end
    end

    raise RedisTransactionAborted if redis_result.nil? # trxn was aborted

    return phone_numbers
  end

public

  def initialize(campaign)
    CallFlow::DialQueue.validate_campaign!(campaign)
    @campaign = campaign
  end

  def size
    redis.zcard keys[:active]
  end

  def range_by_score(key, min, max, opts={})
    redis.zrangebyscore(keys[key], min, max, opts)
  end

  def all(list=:active, options={})
    redis.zrange keys[list], 0, -1, options
  end

  def presented_and_stale
    min = '-inf'
    max = "#{campaign.recycle_rate.hours.ago.to_i}.999"
    range_by_score(:presented, min, max, with_scores: true)
  end

  def next(n)
    # every number in :active set is guaranteed to have a corresponding presentable contact
    zpoppush(n)
  end

  def missing?(phone)
    redis.zscore(keys[:active], phone).nil?
  end

  def insert(scored_members)
    return if scored_members.empty?
    redis.zadd(keys[:active], scored_members)
  end

  def add(household)
    return false if household.presented_recently?

    redis.zadd keys[:active], *memberize(household)
  end

  def remove(phones)
    keys.each do |label, key|
      redis.zrem key, [*phones]
    end
  end

  def dialed(phones)
    redis.zrem keys[:presented], [*phones]
  end
end
