class CallFlow::Call::Storage
  include CallFlow::DialQueue::Util

  attr_reader :account_sid, :call_sid, :namespace

private
  def validate!
    if account_sid.blank? or call_sid.blank?
      raise CallFlow::Call::InvalidParams, "CallFlow::Call::Data requires non-blank account_sid & call_sid."
    end
  end


public
  def initialize(account_sid, call_sid, namespace=nil)
    @account_sid = account_sid
    @call_sid    = call_sid
    @namespace   = namespace
    validate!
  end

  def key
    @key ||= [
      'calls',
      account_sid,
      call_sid,
      namespace
    ].compact.join(':')
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
end

