##
# Maintains a set of hashes where the redis-key & hash-key are components of 
# a phone number and the values are JSON strings of an array of leads.
#
# For example, given a phone number 5554443321, member id of 42
# and a campaign id of 4323, the corresponding redis key will be
# `dial_queue:42:households:5554443` which accesses a redis hash.
# The corresponding hash key will be `321` which will return
# a JSON string of an array of leads.
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
  def keys
    {
      active: "dial_queue:#{campaign.id}:households:active", # redis key/hash/json data
      presented: "dial_queue:#{campaign.id}:households:presented", # redis key/hash/json data
      inactive: "dial_queue:#{campaign.id}:households:inactive", # redis key/hash/json data
      message_drops: "dial_queue:#{campaign.id}:households:message_drops", # redis bitmap
      completed_leads: "dial_queue:#{campaign.id}:households:completed_leads" # redis bitmap
    }
  end

  def keys_for_lua(phone)
    [
      key(phone, :active),
      key(phone, :inactive)
    ]
  end

  def hkey(phone)
    [ key(phone), phone[phone_hkey_index_start..-1] ]
  end

public

  def initialize(campaign, type=:active)
    CallFlow::DialQueue.validate_campaign!(campaign)

    @campaign    = campaign
    @type        = type
  end

  def key(phone, _type=nil)
    _type ||= self.type
    "#{keys[_type]}:#{phone[0..phone_key_index_stop]}"
  end

  def phone_key_index_stop
    (n = ENV['REDIS_PHONE_KEY_INDEX_STOP']).nil? ? -4 : n.to_i
  end

  def phone_hkey_index_start
    phone_key_index_stop + 1
  end

  def exists?
    cursor, results = redis.scan(0, match: "#{keys[:active]}:*")
    results.any?
  end

  def save(phone, members)
    return nil if phone.blank?
    redis.hset( *hkey(phone), members.to_json )
  end

  def find(phone)
    result = redis.hget *hkey(phone)
    if result.blank?
      # todo: raise or log exception here since this should never be the case
      result = []
    else
      result = HashWithIndifferentAccess.new(JSON.parse(result))
    end
    result
  end

  def find_all(phone_numbers)
    return [] if phone_numbers.empty?

    result = {}
    phone_numbers.each{|number| result[number] = find(number)}
    result
  end

  def find_presentable(phone_numbers)
    result = []

    return result if phone_numbers.empty?

    phone_numbers.each do |number|
      house = find(number)
      unless house.empty?
        house[:leads].reject!{|lead| lead_completed?(lead[:sequence])}
        result << house
      end
    end
    result
  end

  def remove_house(phone)
    redis.hdel *hkey(phone)
  end

  def missing?(phone)
    not redis.hexists(*hkey(phone))
  end

  def record_message_drop(sequence)
    redis.setbit(keys[:message_drops], sequence, 1)
  end

  def message_dropped_recorded?(sequence)
    redis.getbit(keys[:message_drops], sequence) > 0
  end

  def record_message_drop_by_phone(phone)
    Wolverine.dial_queue.set_message_drop_bit({
      keys: keys_for_lua(phone) + [keys[:message_drops]],
      argv: [phone, hkey(phone).last]
    })
  end

  def message_dropped?(phone)
    result = Wolverine.dial_queue.get_message_drop_bit({
      keys: keys_for_lua(phone) + [keys[:message_drops]],
      argv: [phone, hkey(phone).last]
    })
    result.to_i > 0
  end

  def no_message_dropped?(phone)
    not message_dropped?(phone)
  end

  def mark_lead_completed(lead_sequence)
    redis.setbit(keys[:completed_leads], lead_sequence, 1)
  end

  def lead_completed?(lead_sequence)
    redis.getbit(keys[:completed_leads], lead_sequence).to_i > 0
  end

  def incomplete_lead_count_for(phone)
    count_leads_with_bit(phone, :completed_leads, 0)
  end

  def count_leads_with_bit(phone, bitmap, bit)
    Wolverine.dial_queue.count_leads_with_bit({
      keys: keys_for_lua(phone) + [keys[bitmap]],
      argv: [phone, hkey(phone).last, bit]
    }).to_i
  end

  def any_incomplete_leads_for?(phone)
    incomplete_lead_count_for(phone) > 0
  end

  def dial_again?(phone)
    if campaign.use_recordings?
      campaign.call_back_after_voicemail_delivery? or no_message_dropped?(phone)
    else
      any_incomplete_leads_for?(phone)
    end
  end

  ##
  # Cache given SQL IDs with associated lead data in redis.
  #
  # :phone: the phone where the lead can be found in redis
  # :uuid_to_id_map: a hash of lead uuids as keys and sql ids as values
  def update_leads_with_sql_ids(phone, uuid_to_id_map)
    Wolverine.dial_queue.update_leads_with_sql_id({
      keys: keys_for_lua(phone),
      argv: [hkey(phone).last, uuid_to_id_map.to_json]
    })
  end
end

