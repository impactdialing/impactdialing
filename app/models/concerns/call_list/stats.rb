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
    keys = [
      campaign.call_list.custom_id_register_key_base
    ]

    Wolverine.list.purge({
      keys: keys,
      argv: []
    })

    custom_id_register_keys = []
    redis_connection_pool.with do |conn|
      conn.scan_each({
        match: "#{campaign.call_list.custom_id_register_key_base}*"
      }) do |key|
      custom_id_register_keys << key
      end
    end

    # redis.scan_each({
    #   match: "#{campaign.call_list.custom_id_register_key_base}*"
    # }) do |key|
    #   custom_id_register_keys << key
    # end
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
    redis_connection_pool.with{|conn| conn.hset(key, hkey, value)}
    # redis.hset(key, hkey, value)
  end

  def [](attribute)
    redis_connection_pool.with{|conn| conn.hget(key, attribute).to_i}    
    # redis.hget(key, attribute).to_i
  end
end

