##
# Class to handle caching selected Voter fields for display to callers.
#
# The :active key is used to cache Script#voter_fields (fields hselected for display when editing a Script).
# 
class CallFlow::Web::ContactFields::Selected
  include CallFlow::DialQueue::Util

  attr_reader :object

private
  def keys
    {
      active: "contact_fields"
    }
  end

  def validate_object_id!
    unless object.respond_to?(:id) and object.id.present? and object.kind_of?(Script)
      raise ArgumentError, "#{self.class} must be instantiated with a saved Script instance."
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
    fields.blank? ? [] : JSON.parse(fields)
  end

  def delete
    redis.hdel keys[:active], object.id
  end
end
