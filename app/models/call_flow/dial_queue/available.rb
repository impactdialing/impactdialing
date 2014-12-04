##
# Class for caching list of voters available for dialing right now.
# 
# Experiments show caching the id and phone as json list items for approx. 560,000 voters
# takes approx. 45-50KB. Extrapolating, I expect 100KB usage for ~1 million entries and
# ~100MB usage for ~1 billion entries.
#
# Based on the above numbers, there should be no issue with storing all available voters
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

private
  def _benchmark
    @_benchmark ||= ImpactPlatform::Metrics::Benchmark.new("dial_queue.#{campaign.account_id}.#{campaign.id}.available")
  end

  def keys
    {
      active: "dial_queue:#{campaign.id}:active"
    }
  end

public

  def initialize(campaign)
    @campaign = campaign
  end

  def size
    redis.zcard keys[:active]
  end

  def peak(list=:active)
    redis.zrange keys[list], 0, -1
  end
  alias :all :peak

  def next(n)
    n = size if n > size
    # every number in :active set is guaranteed to have at least one callable voter
    phone_numbers = redis.zrange keys[:active], 0, (n-1)

    return [] if phone_numbers.empty?

    # remove phone_numbers from :active pool to prevent other callers checking them out
    remove phone_numbers

    return phone_numbers
  end

  def insert(scored_members)
    return if scored_members.empty?
    redis.zadd(keys[:active], scored_members)
  end

  def update_score(voter)
    new_score = score(voter).to_f
    cur_score = redis.zscore(keys[:active], voter.phone).to_f
    if new_score > cur_score
      redis.zadd keys[:active], new_score, voter.phone
      return true
    else
      return false
    end
  end
  alias :add :update_score

  def remove_household(phones)
    redis.zrem keys[:active], [*phones]
  end
  alias :remove :remove_household

end
