class CallFlow::Web::Event
  attr_reader :account_id
  include CallFlow::DialQueue::Util
  private
    def generate_channel_name
      TokenGenerator.uuid
    end

    def key
      @key ||= "call_flow:web:event:#{account_id}"
    end

    def _channel
      @_channel ||= redis.get(key)
    end

  public
    def initialize(account_id)
      if account_id.blank?
        raise CallFlow::BaseArgumentError, "Account ID is required"
      end
      @account_id = account_id
    end

    def channel
      value = _channel
      if value.blank?
        value = generate_channel_name
        redis.set(key, value)
      end
      value
    end
end
