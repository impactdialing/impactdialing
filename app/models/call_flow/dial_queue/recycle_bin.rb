##
# Class for caching list of dialed voters.
# This list is not seeded until a voter is ready to call.
# Once a voter has been added to this list. The voter should
# remain on the list until the associated campaign's recycle rate expires.
#
# When deploying this, it's possible there could be some campaign's with long recycle
# rates (eg 24 hours). So once these changes are deployed to production, make sure
# to run a script to seed the dialed lists for these campaigns to avoid potentially long
# start-up times in the morning as well as to avoid calling household members. Check
# w/ Michael to see if there's any value in this seed'ing first.
class CallFlow::DialQueue::RecycleBin
  attr_reader :campaign

  delegate :recycle_rate, to: :campaign

  include CallFlow::DialQueue::Util

private
  def keys
    {
      dialed: "dial_queue:#{campaign.id}:dialed"
    }
  end

  def entries
    redis.zrange keys[:dialed], 0, -1
  end

  def _benchmark
    @_benchmark ||= ImpactPlatform::Metrics::Benchmark.new("dial_queue.#{campaign.account_id}.#{campaign.id}.dialed")
  end

  def score(voter)
    n = voter.id + voter.last_call_attempt_time.to_i
    "#{n}.#{voter.call_attempts.count}"
  end

public
  def initialize(campaign)
    @campaign = campaign
  end

  def add(voter)
    expire keys[:dialed] do
      redis.zadd keys[:dialed], score(voter), voter.phone
    end
  end

  def remove(voter)
    redis.zrem keys[:dialed], voter.phone
  end

  def size
    redis.zcard keys[:dialed]
  end

  def all
    redis.zrange keys[:dialed], 0, -1
  end
end
