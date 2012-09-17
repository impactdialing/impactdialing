RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
require File.join(RAILS_ROOT, 'lib/redis_connection')
require "eventmachine"
require 'em-http'
require 'em-hiredis'
require 'em-http-request'

module RedisMysql
  module Persist
    
    def self.redis
      redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
      @redis ||= EM::Hiredis.connect(redis_config[ENV['RAILS_ENV']]['call_flow_connection'])      
    end

    def self.next
      redis.blpop('call_completed', 0).callback do |list, data|
        call_data = JSON.parse(data)        
        call_attempt_id = call_data.delete('call_attempt_id')
        update_call_attempt(call_data.delete('call_attempt_id'))
        update_voter(call_data.delete('voter_id'))
        update_caller_session(call_data.delete('caller_session_id'))
        EM.next_tick(&method(:next))   
      end      
    end
    
    def self.update_call_attempt(call_attempt_id)
      call_attempt = CallAttempt.find(call_attempt_id)
      redis_call_attempt = RedisCallAttempt.read(call_attempt_id)
      call_attempt.update_attributes(redis_call_attempt)
      RedisCallAttempt.delete(call_attempt_id)
    end
    
    def self.update_voter(voter_id)
      voter = Voter.find(voter_id)
      redis_voter = RedisVoter.read(voter_id)
      voter.update_attributes(redis_voter)
      RedisVoter.delete(voter_id)
    end
    
    def self.update_caller_session(caller_session_id)
      caller_session = CallerSession.find(caller_session_id)
      redis_caller_session = RedisCallerSession.find(caller_session_id)
      caller_session.update_attributes(redis_caller_session)  
    end
    
    
  end
end

EM.run do
  MonitorTab::Pusher.next
end