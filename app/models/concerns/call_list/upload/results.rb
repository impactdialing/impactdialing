module CallList::Upload::Results
  def self.included(base)
    base.instance_eval do
      extend ClassMethods
      include InstanceMethods
    end
  end

  module ClassMethods
    def redis
      @redis ||= $redis_dialer_connection
    end
  end

  module InstanceMethods
    def redis
      self.class.redis
    end

    def default_results
      HashWithIndifferentAccess.new
    end

    def setup_or_recover_results(_results)
      return default_results unless _results

      HashWithIndifferentAccess.new(_results)
    end

    def update_results(_cursor, _results)
      @cursor = _cursor
      @results = _results

      lua_results.each do |key,count|
        @results[key] = count.to_i
      end
    end

    def dial_queue
      @dial_queue ||= voter_list.campaign.dial_queue
    end

    def lua_results
      redis.hgetall lua_results_key
    end

    def final_results
      _final_results = results.dup

      _final_results[:total_rows] = cursor - 1 # don't count header
      
      return _final_results
    end
  end
end
