class CallFlow::DialQueue::PhoneNumberSet
  attr_reader :campaign

  delegate :recycle_rate, to: :campaign

  include CallFlow::DialQueue::Util
  include CallFlow::DialQueue::SortedSetScore

private
  def log(*args)
    CallFlow::DialQueue.log(*args)
  end

  def keys
    raise "Not Implemented"
  end

  def default_key
    keys.values.first
  end

  def find_key(key_name=nil)
    key_name.nil? ? default_key : keys[key_name]
  end

public
  def initialize(campaign)
    CallFlow::DialQueue.validate_campaign!(campaign)
    @campaign = campaign
  end

  def add(*args)
    raise "Not Implemented"
  end

  def dialed(*args)
    raise "Not Implemented"
  end

  def remove(phones)
    return if phones.blank?

    keys.values.each do |key|
      redis.zrem key, [*phones]
    end
  end
  alias :remove_all :remove

  def exists?
    keys.values.any?{|key| redis.exists(key)}
  end

  def missing?(phone)
    keys.values.all?{|key| redis.zscore(key, phone).nil?}
  end

  def size(key_name=nil)    
    redis_connection_pool.with{|conn| conn.zcard find_key(key_name)}    
    # redis.zcard find_key(key_name)
  end

  def count(key_name=nil, min, max)
    # redis.zcount find_key(key_name), min, max
    redis_connection_pool.with{|conn| conn.zcount find_key(key_name), min, max}
  end

  def range_by_score(key_name, min, max, opts={})  
    redis_connection_pool.with{|conn| conn.zrangebyscore find_key(key_name), min, max, opts}
    # redis.zrangebyscore find_key(key_name), min, max, opts
  end

  def all(key_name=nil, options={})
    redis_connection_pool.with{|conn| conn.zrange find_key(key_name), 0, -1, options}
    # redis.zrange find_key(key_name), 0, -1, options
  end

  def each(key_name=nil, options={}, &block)    
    redis_connection_pool.with{|conn| conn.zscan_each find_key(key_name), options, &block}  
    # redis.zscan_each find_key(key_name), options, &block
  end

  ##
  # Removes members in batches of 100 then deletes the key.
  # Batch removal + key deletion provides better throughput
  # than straight key deletion.
  def purge!
    klass = self.class.to_s.split('::').last.downcase
    keys.values.each do |key|
      slices = (size / 100.0).floor - 1
      slices.times do |n|
        campaign.timing("dial_queue.#{klass}.purge.zrembyrank.time") do
          redis.zremrangebyrank key, 0, 100
        end
      end
      campaign.timing("dial_queue.#{klass}.purge.del.time") do
        redis.del key
      end
    end
  end
end
