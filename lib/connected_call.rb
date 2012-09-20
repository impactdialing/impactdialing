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
    
    def self.call_connected(call_attempt_id)
      call_attempt = CallAttempt.find(call_attempt_id)
      redis_call_attempt = RedisCallAttempt.read(call_attempt_id)
      campaign = call_attempt.campaign
      MonitorEvent.incoming_call_request(campaign)      
      MonitorEvent.voter_connected(campaign) 
      MonitorEvent.create_caller_notification(campaign.id, redis_call_attempt['caller_session_id'], redis_call_attempt["status"])      
    end
    
    def self.end_answered_call(call_attempt_id)
      call_attempt = CallAttempt.find(call_attempt_id)
      redis_call_attempt = RedisCallAttempt.read(call_attempt_id)
      campaign = call_attempt.campaign            
      MonitorEvent.voter_disconnected(campaign)
      MonitorEvent.create_caller_notification(campaign.id, redis_call_attempt['caller_session_id'], redis_call_attempt["status"])  
    end    
    
    def self.wrapup(call_attempt_id)
      call_attempt = CallAttempt.find(call_attempt_id)
      campaign = call_attempt.campaign                  
      redis_call_attempt = RedisCallAttempt.read(call_attempt_id)
      MonitorEvent.voter_response_submitted(campaign)
      MonitorEvent.create_caller_notification(campaign.id, redis_call_attempt['caller_session_id'], "On hold")
      RedisCallMysql.call_completed(call_attempt.id)            
    end    
    
    def self.caller_connected(caller_session_id)
      caller_session = CallerSession.find(caller_session_id)
      campaign = caller_session.campaign
      MonitorEvent.caller_connected(campaign)
      MonitorEvent.create_caller_notification(campaign.id, caller_session.id, "caller_connected", "add_caller")    
    end
    
    def self.caller_disconnected(caller_session_id)
      caller_session = CallerSession.find(caller_session_id)
      campaign = caller_session.campaign
      MonitorEvent.caller_disconnected(campaign)
      MonitorEvent.create_caller_notification(campaign.id, caller_session.id, "caller_disconnected", "remove_caller")
    end
    
    
  end
end

EM.run do
  Connected::Call.next
end