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
  
  
  def self.monitor_connection
    rails_env = ENV['RAILS_ENV'] || 'development'
    redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
    uri = URI.parse(redis_config[rails_env]['monitor_redis'])
    Redis.new(:host => uri.host, :port => uri.port)      
  end
  
  def self.monitor_connection_em
    rails_env = ENV['RAILS_ENV'] || 'development'
    redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
    EM::Hiredis.connect(redis_config[rails_env]['monitor_redis'])
  end
  
  def self.common_connection
    redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")    
    rails_env = ENV['RAILS_ENV']
    if rails_env == "test"
      uri = URI.parse(redis_config[rails_env]['common'])
      Redis.new(:host => uri.host, :port => uri.port)            
    else
      $redis_common_connection ||= EM::Hiredis.connect(redis_config[rails_env]['common']) 
    end
    
  end
    
  
end