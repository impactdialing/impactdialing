class CallFlow::Call::Storage
  include CallFlow::DialQueue::Util

  attr_reader :group_key, :object_key, :namespace

private
  def validate!
    if group_key.blank? or object_key.blank?
      raise CallFlow::Call::InvalidParams, "CallFlow::Call::Storage requires non-blank group_key & object_key."
    end
  end


public
  def initialize(group_key, object_key, namespace=nil)
    @group_key  = group_key
    @object_key = object_key
    @namespace  = namespace
    validate!
  end

  def self.key(group_key, object_key, namespace=nil)
    [
      'calls',
      group_key,
      object_key,
      namespace
    ].compact.join(':')
  end

  def key
    @key ||= self.class.key(group_key, object_key, namespace)
  end

  def [](property)
    redis.hget(key, property)
  end

  def []=(property, value)
    redis.hset(key, property, value)
  end

  def save(hash)
    redis.mapped_hmset(key, hash)
  end

  def multi(&block)
    redis.multi(&block)
  end

  def attributes
    HashWithIndifferentAccess.new(redis.hgetall(key))
  end
end

