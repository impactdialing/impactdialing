RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
require File.join(RAILS_ROOT, 'lib/redis_connection')
require "eventmachine"
require 'em-http'
require 'em-hiredis'
require 'em-http-request'

module Connected
  module Call
    
    def self.redis
      redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
      @redis ||= EM::Hiredis.connect(redis_config[ENV['RAILS_ENV']]['common'])      
    end

    def self.next
      redis.blpop('connected_call_notification', 0).callback do |list, data|
        notification = JSON.parse(data)        
        identity = notification.delete('identity')
        event = notification.delete('event')
        self.send(event, identity)
        EM.next_tick(&method(:next))   
      end      
    end
    
    
    
    def self.wrapup(call_attempt_id)
      RedisCallMysql.call_completed(call_attempt.id)            
    end    
        
    def self.caller_disconnected(caller_session_id)
    end
    
    
  end
end

EM.run do
  Connected::Call.next
end