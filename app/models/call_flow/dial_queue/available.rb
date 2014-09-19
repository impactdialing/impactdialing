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
class CallFlow::DialQueue::Available
  attr_reader :campaign

private
  def redis
    $redis_call_flow_connection
  end

  def seed_limit
    (ENV['DIAL_QUEUE_AVAILABLE_SEED_LIMIT'] || 10).to_i
  end

  def voter_limit
    (ENV['DIAL_QUEUE_AVAILABLE_LIMIT'] || 1000).to_i
  end

  def voter_reload_threshold
    (ENV['DIAL_QUEUE_AVAILABLE_RELOAD_THRESHOLD'] || seed_limit).to_i
  end

  def next_voters(limit)
    dnc_numbers      = campaign.account.blocked_numbers.for_campaign(campaign).pluck(:number)
    available_voters = campaign.all_voters.available_list(campaign).where('id NOT IN (?)', active_ids).without(dnc_numbers)

    voters = available_voters.where('id > ?', last_loaded_id).limit(limit)
    if voters.count.zero?
      voters = available_voters.limit(limit)
    end
    voters.select([:id])
  end

  def active_ids
    # -1 entry here ensures consistent results when there are no active ids
    [-1] + peak(:active).map{|v| JSON.parse(v)['id']}
  end

  def last_loaded_id
    id = 0
    last_active_item = redis.lrange(keys[:active], 0, 1)
    if last_active_item.first.present?
      id = JSON.parse(last_active_item.first)['id']
    end
    id
  end

  def keys
    {
      active: "dial_queue:available:active:#{campaign.id}"
    }
  end

  def expire(key, &block)
    set_expire = (not redis.exists(key))
    out        = yield

    if set_expire
      # expire this key at 23:59 tonight in the appropriate time zone
      today       = Date.today
      # campaign.end_time only stores the hour
      expire_time = Time.mktime(today.year, today.month, today.day, campaign.end_time.hour)
      redis.expireat key, expire_time.in_time_zone(campaign.time_zone).end_of_day.to_i
    end

    return out
  end

public

  def initialize(campaign)
    @campaign = campaign
  end

  def prepend(voters_to_prepend=[])
    if voters_to_prepend.empty?
      voters_to_prepend = next_voters(voter_limit)
    end

    return if voters_to_prepend.empty?

    expire keys[:active] do
      redis.lpush keys[:active], voters_to_prepend.map{|voter| voter.to_json(root: false)}
    end
  end

  def seeded?
    (not size.nil?) and (not size.zero?)
  end

  def seed
    return if seeded?

    prepend(next_voters(seed_limit))
  end

  def refresh
    return if not seeded?
    
    redis.multi do
      redis.del keys[:active]
      prepend
    end
  end

  def size
    redis.llen keys[:active]
  end

  def peak(list=:active)
    redis.lrange keys[list], 0, -1
  end

  def next(n)
    result = []
    n = size if n > size
    n.times do
      result << redis.rpop(keys[:active])
    end

    result.map{|r| JSON.parse(r)}
  end

  def last
    redis.lindex keys[:active], 0
  end

  def reload_if_below_threshold
    prepend if size <= voter_reload_threshold
  end

  def clear
    redis.multi do
      redis.del keys[:active]
    end
  end
end