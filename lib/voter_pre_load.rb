RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')

require 'em-http-request'

module Voter
  module PreLoad
    def self.redis
      @redis = RedisConnection.call_flow_connection
    end

    def self.next
      redis
      redis.blpop('monitor_notifications', 0).callback do |list, data|
        EM.next_tick(&method(:next))   
      end      
    end
        
  end
end

EM.run do
  Voter::PreLoad.next
end