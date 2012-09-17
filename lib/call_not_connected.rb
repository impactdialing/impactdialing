RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
require File.join(RAILS_ROOT, 'lib/redis_connection')
require "eventmachine"
require 'em-http'
require 'em-hiredis'
require 'em-http-request'

module Call
  module NotConnected
    
    def self.redis
      redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
      @redis ||= EM::Hiredis.connect(redis_config[ENV['RAILS_ENV']]['common'])      
    end

    def self.next
      redis.blpop('notconnected_call_notification', 0).callback do |list, data|
        notification = JSON.parse(data)        
        call_attempt_id = notification.delete('call_attempt_id')
        event = notification.delete('event')
        self.send(event, call_attempt_id)
        EM.next_tick(&method(:next))   
      end      
    end    
    
    def self.call_abandoned(call_attempt_id)
      call_attempt = CallAttempt.find(call_attempt_id)
      campaign = call_attempt.campaign      
      # RedisCampaignCall.move_ringing_to_abandoned(campaign.id, call_attempt.id)
      # MonitorEvent.incoming_call_request(campaign)
      RedisCall.call_completed(call_attempt.id)
    end
    
    
    def self.answered_by_machine(call_attempt_id)
      call_attempt = CallAttempt.find(call_attempt_id)
      campaign = call_attempt.campaign                  
      # MonitorEvent.incoming_call_request(campaign)
    end
    
    def self.end_answered_by_machine(call_attempt_id)
      call_attempt = CallAttempt.find(call_attempt_id)
      campaign = call_attempt.campaign                        
      RedisCall.call_completed(call_attempt.id)
      # MonitorEvent.incoming_call_request(campaign)              
    end
    
    def self.end_unanswered_call(call_attempt_id)
      call_attempt = CallAttempt.find(call_attempt_id)
      campaign = call_attempt.campaign                              
      # RedisCampaignCall.move_ringing_to_completed(campaign.id, call_attempt.id)
      RedisCall.call_completed(call_attempt.id)
    end
    
    
  end
end

EM.run do
  Call::NotConnectedConnected.next
end