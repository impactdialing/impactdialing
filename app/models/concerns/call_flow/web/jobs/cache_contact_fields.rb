require 'librato_resque'

class CallFlow::Web::Jobs::CacheContactFields
  @queue = :dial_queue
  extend LibratoResque

  def self.perform(script_id)
    script         = Script.find(script_id)
    contact_fields = CallFlow::Web::ContactFields::Selected.new(script)
    contact_fields.cache_raw(script.voter_fields)
  end
end
