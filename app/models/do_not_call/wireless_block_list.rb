module DoNotCall
  class WirelessBlockList
  private
    def self.redis
      @redis ||= Redis.new
    end

    def self.key
      "do_not_call:wireless_block"
    end

    def self.delete_all
      redis.del key
    end

  public
    def self.cache(file)
      delete_all
      parser = WirelessBlockParser.new(file)
      parser.in_batches do |strs_of_7_digits|
        redis.sadd key, strs_of_7_digits
      end
    end

    def self.exists?(phone)
      redis.sismember(key, phone[-10..-4])
    end

    def self.all
      redis.smembers(key)
    end
  end
end
