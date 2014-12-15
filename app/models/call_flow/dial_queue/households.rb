##
# Maintains a set of hashes where the redis-key & hash-key are components of 
# a phone number and the values are JSON strings of an array of ids.
#
# For example, given a phone number 5554443321, member id of 42
# and a campaign id of 4323, the corresponding redis key will be
# `dial_queue:42:households:55544` which accesses a redis hash.
# The corresponding hash key will be `43321` which will return
# a JSON string of an array of ids.
#
# The key partitioning scheme uses the first 5 digits of the number
# as a component to the redis key and the remaining digits of the number
# as the component to the hash key. Some numbers may have more digits than
# others, eg if they include a country code. Currently no attempt is made
# to normalize phone numbers across country codes. For example if the number
# `5554443321` is added and then `15554443321` is added, they will define
# different households.
#
class CallFlow::DialQueue::Households
  attr_reader :campaign, :type

  delegate :recycle_rate, to: :campaign

  include CallFlow::DialQueue::Util

private
  def _benchmark
    @_benchmark ||= ImpactPlatform::Metrics::Benchmark.new("dial_queue.#{campaign.account_id}.#{campaign.id}.available")
  end

  def keys
    {
      active: "dial_queue:#{campaign.id}:households:active"
    }
  end

  def key(phone)
    "#{keys[type]}:#{phone[0..4]}"
  end

  def hkey(phone)
    [ key(phone), phone[5..-1] ]
  end

  def match?(member_one, member_two)
    member_one['id'] == member_two['id']
  end

public

  def initialize(campaign, type=:active)
    @campaign = campaign
    @type     = type
  end

  def add(phone, member)
    members = find(phone)
    if (index = members.index{|membr| match?(membr, member)})
      members[index] = member
    else
      members << member
    end
    save(phone, members)
    members
  end

  def remove_member(phone, member)
    members = find(phone)
    members.reject!{|membr| match?(membr, member)}
    save(phone, members)
  end

  def save(phone, members)
    redis.hset *hkey(phone), members.to_json
  end

  def find(phone)
    result = redis.hget *hkey(phone)
    if result.blank?
      result = []
    else
      result = JSON.parse(result).map{|r| HashWithIndifferentAccess.new(r)}
    end
    result
  end

  def find_all(phone_numbers)
    return [] if phone_numbers.empty?

    result = {}
    phone_numbers.each{|number| result[number] = find(number)}
    result
  end

  def remove_house(phone)
    redis.hdel *hkey(phone)
  end

  def missing?(phone)
    not redis.hexists(*hkey(phone))
  end
end
