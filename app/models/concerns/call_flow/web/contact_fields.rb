##
# Class to handle caching selected Voter fields for display to callers.
#
# The :active key is used to cache Script#voter_fields (fields hselected for display when editing a Script).
# 
class CallFlow::Web::ContactFields
  attr_reader :script, :account

private
  def redis
    Redis.new
  end

  def validate_object_id!
    unless object.respond_to?(:id) and object.id.present?
      raise ArgumentError, "#{self.class} must be instantiated with an instance that returns some non-nil value for #id"
    end
  end

public

  def initialize(objects)
    if objects[:script]
      @script = objects[:script] 
      @account = @script.account
    end
  end

  def selected
    @selected ||= CallFlow::Web::ContactFields::Selected.new(script)
  end

  def options
    @options ||= CallFlow::Web::ContactFields::Options.new(account)
  end
end

