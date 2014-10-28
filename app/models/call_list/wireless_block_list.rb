module CallList
  class WirelessBlockList
  private
    def self.redis
      @redis ||= Redis.new
    end

    def self.key
      "wireless_numbers:block"
    end

    def self.delete_all
      redis.del key
    end

  public
    def self.cache
      delete_all
      parser = WirelessBlockParser.new
      parser.in_batches do |strs_of_7_digits|
        redis.sadd key, strs_of_7_digits
      end
    end

    def self.exists?(str_of_7_digits)
      redis.sismember(key, str_of_7_digits)
    end
  end
end
