class CallFlow::Web::ContactFields::Options
  include CallFlow::DialQueue::Util

  attr_reader :object

private
  def key
    "contact_fields:options:#{object.id}"
  end

  def validate_object!
    unless object.kind_of?(Account) and (not object.new_record?)
      raise ArgumentError, "#{self.class} must be instantiated with a saved Account instance."
    end
  end

  def clean(fields)
    fields.reject{|field| field.blank?}
  end

public
  def initialize(object)
    @object = object
    validate_object!
  end

  def save(new_fields)
    clean_fields = clean(new_fields)
    
    unless clean_fields.empty?
      redis.sadd key, clean_fields
    end
  end

  def all
    redis.smembers key
  end
end
