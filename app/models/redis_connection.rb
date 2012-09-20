require "eventmachine"
require 'em-http'
require 'em-hiredis'

class RedisConnection
  
  def self.call_flow_connection
      rails_env = ENV['RAILS_ENV'] || 'development'
      redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
      uri = URI.parse(redis_config[rails_env])
      Redis.new(:host => uri.host, :port => uri.port)      
  end
  
end