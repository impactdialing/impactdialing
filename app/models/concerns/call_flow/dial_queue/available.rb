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
class CallFlow::DialQueue::Available < CallFlow::DialQueue::PhoneNumberSet
public
  def keys
    {
      active: "dial_queue:#{campaign.id}:active",
      presented: "dial_queue:#{campaign.id}:presented"
    }
  end

  def presented_and_stale
    min = '-inf'
    max = "#{campaign.recycle_rate.hours.ago.to_i}.999"
    range_by_score(:presented, min, max, with_scores: true)
  end

  def next(n)
    json = Wolverine.dial_queue.load_next_available({
      keys: [keys[:active], keys[:presented]],
      argv: [n, Time.now.utc.to_f]
    })

    JSON.parse(json || '[]')
  end

  def insert(scored_members)
    return if scored_members.empty?
    redis.zadd(keys[:active], scored_members)
  end

  def dialed(phones)
    redis.zrem keys[:presented], [*phones]
  end
end

