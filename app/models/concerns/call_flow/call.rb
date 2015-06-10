module CallFlow
  class Call
    attr_reader :type, :cache_params, :account_sid, :call_sid
  private
    def redis
      @redis ||= Redis.new
    end

    def twilio_params(raw_params)
      CallFlow::TwilioCallParams.load(raw_params)
    end

    def key
      "calls:#{account_sid}:#{call_sid}"
    end

  public
    def initialize(raw_params)
      @cache_params = twilio_params(raw_params)
      @account_sid  = cache_params['AccountSid']
      @call_sid     = cache_params['CallSid']
    end

    def update_history(state)
      redis.hset(key, state, Time.now.utc)

      if redis.ttl(key) < 0
        redis.expire(key, 1.day)
      end
    end

    def state_visited?(state)
      redis.hexists(key, state)
    end

    def state_missed?(state)
      not state_visited?(state)
    end

    def exists?
      redis.exists key
    end

    def del
      redis.del key
    end
  end
end
