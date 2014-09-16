class CallFlow::DialQueue::Available
  attr_reader :campaign

private
  def redis
    $redis_call_flow_connection
  end

  def voter_limit
    (ENV['DIAL_QUEUE_AVAILABLE_LIMIT'] || 100).to_i
  end

  def voter_reload_threshold
    (ENV['DIAL_QUEUE_AVAILABLE_RELOAD_THRESHOLD'] || 10).to_i
  end

  def next_voters
    # recently_dialed_household_numbers = Voter.recently_dialed_households(recycle_rate).pluck(:phone)
    # without_numbers                   = blocked_numbers + recently_dialed_household_numbers

    # not_dialed_queue = voters.not_dialed.without(without_numbers).enabled
    # retry_queue      = voters.next_in_recycled_queue(recycle_rate, without_numbers)
    # _not_skipped     = not_dialed_queue.not_skipped.first
    # _not_skipped     ||= retry_queue.not_skipped.first

    # if _not_skipped.nil?
    #   if current_voter_id.present?
    #     voter = not_dialed_queue.where(["id > ?", current_voter_id]).first
    #   end
    #   voter ||= not_dialed_queue.first

    #   if current_voter_id.present?
    #     voter ||= retry_queue.where(["id > ?", current_voter_id]).first
    #   end
    #   voter ||= retry_queue.first
    # else
    #   if current_voter_id.present?
    #     voter = not_dialed_queue.where(["id > ?", current_voter_id]).not_skipped.first
    #   end
    #   voter ||= not_dialed_queue.not_skipped.first

    #   if current_voter_id.present?
    #     voter ||= retry_queue.where(["id > ?", current_voter_id]).not_skipped.first
    #   end
    #   voter ||= _not_skipped
    # end

    # return voter

    dnc_numbers = campaign.account.blocked_numbers.for_campaign(campaign).pluck(:number)

    all_voters  = campaign.all_voters.enabled.active.without(dnc_numbers) #.available(campaign)
    cache_queue = all_voters.not_dialed.where('id > ?', last_loaded_id).limit(voter_limit)

    return cache_queue.select([:id, :phone]) if cache_queue.count == voter_limit

    extras_limit = voter_limit - cache_queue.count
    extras       = all_voters.next_in_recycled_queue(campaign.recycle_rate, dnc_numbers).limit(extras_limit)

    cache_queue.select([:id, :phone]) + extras.select([:id, :phone])
  end

  def last_loaded_id
    redis.get(keys[:last_loaded_id]) || 0
  end

  def last_loaded_id=(id)
    redis.set(keys[:last_loaded_id], id)
  end

  def keys
    {
      active: "dial_queue:available:active:#{campaign.id}",
      processing: "dial_queue:available:processing:#{campaign.id}",
      last_loaded_id: "dial_queue:available:last_loaded_id:#{campaign.id}"
    }
  end

  def expire(key, &block)
    set_expire = (not redis.exists(key))
    out        = yield

    if set_expire
      redis.expireat key, campaign.end_time.in_time_zone(campaign.time_zone).end_of_day.to_i
    end

    return out
  end

public

  def initialize(campaign)
    @campaign = campaign
  end

  def prepend
    voters_to_prepend   = next_voters.reverse
    # binding.pry
    return if voters_to_prepend.empty?

    self.last_loaded_id = voters_to_prepend.first.id

    expire keys[:active] do
      redis.rpush keys[:active], voters_to_prepend.map{|voter| voter.to_json(root: false)}
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
      result << redis.rpoplpush(keys[:active], keys[:processing])
    end
    
    prepend if size <= voter_reload_threshold

    result.map{|r| JSON.parse(r)}
  end

  def clear
    redis.multi do
      redis.del keys[:active]
      redis.del keys[:processing]
      redis.del keys[:last_loaded_id]
    end
  end
end