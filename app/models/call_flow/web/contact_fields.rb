##
# Class to handle caching of lists of +Voter+ fields (custom & system).
# 
class CallFlow::Web::ContactFields
  attr_reader :object

private
  def keys
    {
      active: "contact_fields"
    }
  end

  def redis
    Redis.new
  end

  def validate_object_id!
    unless object.respond_to?(:id) and object.id.present?
      raise ArgumentError, "#{self.class} must be instantiated with an instance that returns some non-nil value for #id"
    end
  end

public

  def initialize(object)
    @object = object
    validate_object_id!
  end

  def cache(fields)
    redis.hset keys[:active], object.id, fields.to_json
  end

  def cache_raw(fields_json)
    redis.hset keys[:active], object.id, fields_json
  end

  def data
    fields = redis.hget(keys[:active], object.id)
    fields.nil? ? [] : JSON.parse(fields)
  end
end
