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
    # campaign.reload
    dnc_numbers      = campaign.account.blocked_numbers.for_campaign(campaign).pluck(:number)
    available_voters = campaign.all_voters.available_list(campaign).without(dnc_numbers)
    # binding.pry
    voters = available_voters.where('id > ?', last_loaded_id).limit(voter_limit).select([:id, :phone])
    if voters.count.zero?
      # print "Zero available_voters w/ id > #{last_loaded_id}\n"
      voters = available_voters.where('id NOT IN (?)', active_ids).limit(voter_limit).select([:id, :phone])
    end
    # print "Returning #{voters.count} voters without #{active_ids}\n"
    voters
  end

  def active_ids
    # -1 entry here ensures consistent results when there are no active ids
    [-1] + peak(:active).map{|v| JSON.parse(v)['id']}
  end

  def last_loaded_id
    last_active_item = redis.lrange(keys[:active], 0, 1)
    if last_active_item.first.present?
      id = JSON.parse(last_active_item.first)['id']
      # print "last_loaded_id returning active #{id}\n\n"
      return id
    end
    
    last_processing_item = redis.lrange(keys[:processing], 0, 1)
    if last_processing_item.first.present?
      id = JSON.parse(last_processing_item.first)['id']
      # print "last_loaded_id returning processing #{id}\n\n"
      return id
    end
    
    0
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

  def prepend
    voters_to_prepend = next_voters
    return if voters_to_prepend.empty?

    expire keys[:active] do
      redis.lpush keys[:active], voters_to_prepend.map{|voter| voter.to_json(root: false)}
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

    result.map{|r| JSON.parse(r)}
  end

  def reload_if_below_threshold
    prepend if size <= voter_reload_threshold
  end

  def clear
    redis.multi do
      redis.del keys[:active]
      redis.del keys[:processing]
      redis.del keys[:last_loaded_id]
    end
  end
end