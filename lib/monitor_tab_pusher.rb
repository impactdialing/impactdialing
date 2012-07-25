RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
require File.join(RAILS_ROOT, 'lib/redis_connection')
require 'em-http-request'

module MonitorTab
  module Pusher
    def self.redis
      @redis = RedisConnection.monitor_connection_em
    end

    def self.next
      redis.blpop('monitor_notifications', 0).callback do |list, data|
        notification = JSON.parse(data)        
        channel = notification.delete('channel')
        campaign_id = notification.delete('campaign')
        type = notification.delete('type')
        puts type
        if type == "campaign"        
          redis.hgetall("moderator:#{campaign_id}").callback { |campaign_info|
            campaign_deferrable = ::Pusher[channel].trigger_async('update_campaign_info', Hash[*campaign_info.flatten])
            campaign_deferrable.callback {}
            campaign_deferrable.errback { |error| puts error }                    
           }
        else
          caller_session_id = notification.delete('caller_session')
          event = notification.delete('event')  
          puts "Monitor Pusher Caller: #{event}"        
          caller_deferrable = ::Pusher[channel].trigger_async('update_caller_info', {caller_session: caller_session_id, event: event})
          caller_deferrable.callback {}
          caller_deferrable.errback { |error| puts error }                    
        end
      EM.next_tick(&method(:next))   
      end      
    end
  end
end

EM.run do
  MonitorTab::Pusher.next
end