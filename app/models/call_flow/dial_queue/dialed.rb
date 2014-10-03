##
# Class for caching list of dialed voters
class CallFlow::DialQueue::Dialed
  attr_reader :campaign

  include CallFlow::DialQueue::Util

private
  def keys
    {
      dialed: "dial_queue:dialed:#{campaign.id}"
    }
  end

public
  def initialize(campaign)
    @campaign = campaign
  end

  def filter_disabled?
    ENV['ENABLE_HOUSEHOLDING_FILTER'].to_i.zero?
  end

  def household_dialed(phone_number, call_time)
    expire keys[:dialed] do
      redis.hset keys[:dialed], phone_number, call_time
    end
  end

  def filter(voters)
    return voters if voters.empty? or filter_disabled?

    phone_numbers = voters.map{|v| v['phone']}
    call_times    = redis.hmget keys[:dialed], phone_numbers

    call_times.each_with_index do |call_time, i|
      next if call_time.nil?

      if call_time > campaign.recycle_rate.hours.ago
        voters[i] = nil
      end
    end
    
    voters.compact
  end

  def size
    redis.hlen keys[:dialed]
  end

  def peak(list=:dialed)
    redis.hgetall keys[list]
  end
end
