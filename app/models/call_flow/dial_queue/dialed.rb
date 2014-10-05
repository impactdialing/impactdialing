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

  def entries
    redis.hgetall keys[:dialed]
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

  def numbers
    numbers = []
    entries.each do |phone,time|
      numbers << phone if time > recycle_rate
    end
    numbers
  end

  def recycle_rate
    @threshold ||= campaign.recycle_rate.hours.ago
  end

  def filter(voters)
    return voters if voters.empty? or filter_disabled?

    block = []
    voters.each_with_index do |voter, i|
      block << i if numbers.include?(voter['phone'])
    end

    block.each{|i| voters[i] = nil}
    
    voters.compact
  end

  def size
    redis.hlen keys[:dialed]
  end

  def peak(list=:dialed)
    redis.hgetall keys[list]
  end
end
