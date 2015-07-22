class CallFlow::Web::ContactFields::Options
  include CallFlow::DialQueue::Util

  attr_reader :object

private
  def key
    "contact_fields:options:#{object.id}"
  end

  def validate_object!
    unless object.kind_of?(Account) and (not object.new_record?)
      raise ArgumentError, "#{self.class} must be isntantiated with a saved Account instance."
    end
  end

public
  def initialize(object)
    @object = object
    validate_object!
  end

  def save(new_fields)
    redis.sadd key, new_fields
  end

  def all
    redis.smembers key
  end
end
