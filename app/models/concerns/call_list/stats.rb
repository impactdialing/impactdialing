class CallList::Stats
  attr_reader :record

  include CallFlow::DialQueue::Util
  extend CallFlow::DialQueue::Util

private
  def namespace
    klass = record.kind_of?(Campaign) ? Campaign : record.class
    "list:#{klass.to_s.underscore}:#{record.id}"
  end

public
  def self.purge(campaign)
    voter_lists_stat_keys = campaign.lists.map do |voter_list|
      self.new(voter_list).key
    end
    keys = [
      campaign.call_list.stats.key,
      campaign.call_list.custom_id_register_key_base
    ]
    keys += voter_lists_stat_keys

    Wolverine.list.purge({
      keys: keys,
      argv: []
    })

    custom_id_register_keys = []
    cursor = nil
    redis.scan_each({
      match: "#{campaign.call_list.custom_id_register_key_base}*"
    }) do |key|
      custom_id_register_keys << key
    end
    Wolverine.list.purge({
      keys: custom_id_register_keys.uniq,
      argv: []
    })
  end

  def initialize(record)
    @record = record
  end

  def key
    "#{namespace}:stats"
  end

  def reset(hkey, value)
    redis.hset(key, hkey, value)
  end

  def [](attribute)
    redis.hget(key, attribute).to_i
  end
end

