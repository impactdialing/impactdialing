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
  attr_reader :campaign, :dialed

  delegate :recycle_rate, to: :campaign

  include CallFlow::DialQueue::Util

private
  def _benchmark
    @_benchmark ||= ImpactPlatform::Metrics::Benchmark.new("dial_queue.#{campaign.account_id}.#{campaign.id}.available")
  end

  def all_voters
    campaign.all_voters.available_list(campaign).select([
      'DISTINCT(voters.phone)',
      'voters.id',
      'voters.last_call_attempt_time
    '])
  end

  def top_off_voters(&block)
    all_voters.where('id > ?', last_loaded_id).find_in_batches(batch_size: 5000, &block)
    redis.del keys[:last_loaded_id]
  end

  def seed_voters
    seeds               = all_voters.order('voters.id').limit(5000)
    # self.last_loaded_id = seeds.last.id
    return seeds
  end

  def last_loaded_id
    redis.get keys[:last_loaded_id]
  end

  def last_loaded_id=(val)
    redis.set keys[:last_loaded_id], val
  end

  def keys
    {
      active: "dial_queue:#{campaign.id}:active",
      last_loaded_id: "dial_queue:#{campaign.id}:last_loaded_id",
      voter_pool: "dial_queue:#{campaign.id}:voter_pool"
    }
  end

  def count_call_attempts(voters)
    ids                  = voters.map(&:id)
    @call_attempt_counts = CallAttempt.where(voter_id: ids).group(:voter_id).count
  end

  def score(voter)
    x = if voter.skipped?
          voter.skipped_time.to_i # force skipped voters to rank before called voters
        else
          voter.last_call_attempt_time.to_i
        end

    n = voter.id + x
    # n = "#{voter.id}#{x}"
    "#{n}.#{@call_attempt_counts[voter.id]}"
  end

  def memberize(voter)
    [score(voter), voter.phone]
  end

  def memberize_voters(voters)
    count_call_attempts(seed_voters)

    voters.map do |voter|
      memberize(voter)
    end
  end

  def cache_households(numbers)
    # numbers.each_slice(3000) do |number_slice|
      last_id     = 0
      voters      = campaign.all_voters.available_list(campaign).where(phone: numbers)
      households  = {}
      set_members = []
      count_call_attempts(voters)

      voters.each do |voter|
        households[voter.phone] ||= []

        if households[voter.phone].empty?
          set_members << [score(voter), voter.phone]
        end

        households[voter.phone] << {id: voter.id, last_call_attempt_time: voter.last_call_attempt_time}
        last_id = voter.id
      end

      return last_id if households.empty? and set_members.empty?

      unless households.empty?
        # cache voters by phone number
        hmargs = households.map{|phone, members| [phone, members.to_json]}
        expire keys[:voter_pool] do
          redis.hmset keys[:voter_pool], *hmargs
        end
      end

      # cache phone numbers by score
      unless set_members.empty?
        expire keys[:active] do
          redis.zadd keys[:active], set_members
        end
      end
      last_id
    # end
  end

public

  def initialize(campaign, dialed)
    @campaign = campaign
    @dialed   = dialed
  end

  def top_off
    # top_off_voters do |voters|
    #   redis.zadd keys[:active], memberize_voters(voters)
    # end

    campaign.all_voters.available_list(campaign).
    select('DISTINCT(voters.phone), id').
    # where('id > ?', last_loaded_id).
    where('phone NOT IN (?)', [peak(:active)] + [-1]).
    find_in_batches(batch_size: 3000) do |numbers| 
      self.last_loaded_id = cache_households(numbers.map(&:phone))
    end
  end

  def seeded?
    (not size.nil?) and (not size.zero?)
  end

  def seed
    return if seeded?

    all_numbers = campaign.all_voters.available_list(campaign).select('DISTINCT(voters.phone)').limit(3000).pluck(:phone)
    self.last_loaded_id = cache_households(all_numbers)
  end

  def refresh
    return if not seeded?

    redis.zdel keys[:active]
    seed
  end

  def size
    redis.zcard keys[:active]
  end

  def peak(list=:active)
    redis.zrange keys[list], 0, -1
  end

  def next(n)
    n             = size if n > size
    # every number in :active set is guaranteed to have at least one callable voter
    phone_numbers = redis.zrange keys[:active], 0, (n-1)
    return [] if phone_numbers.empty?
    households    = redis.hmget keys[:voter_pool], phone_numbers # get array of households as json strings

    # since we know every number in :active has at least one callable voter,
    # and recycle rate is respected per phone number, it is acceptable to simply
    # pull the first voter from each household.
    voters = households.compact.map{|voters| JSON.parse(voters).first}

    # remove phone_numbers from :active pool to prevent other callers checking them out
    remove_household phone_numbers

    return voters
  end

  def update_score(voter)
    count_call_attempts([voter])
    redis.zadd keys[:active], score(voter), voter.phone
  end

  def remove_household(phone)
    redis.zrem keys[:active], phone
  end
end
