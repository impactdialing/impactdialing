module DoNotCall
  def self.redis_url_configured?
    redis_url.present?
  end

  def self.redis_url
    ENV['DO_NOT_CALL_REDIS_URL']
  end

  def self.redis
    @redis ||= if redis_url_configured?
                 Redis.new(url: redis_url)
               else
                 Redis.new
               end
  end

  def self.s3_root
    "_system/do_not_call"
  end

  def self.s3_filepath(filename)
    raise ArgumentError if filename.blank?

    "#{DoNotCall.s3_root}/#{filename}"
  end

  def self.ported_file_url
    ENV['DO_NOT_CALL_PORTED_URL']
  end

  def self.block_file_url
    ENV['DO_NOT_CALL_BLOCK_URL']
  end

  def self.auth_ids
    {
      ported: ported_file_url,
      block: block_file_url
    }
  end
end