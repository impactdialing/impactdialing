RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')
require File.join(RAILS_ROOT, 'lib/redis_connection')
require "eventmachine"
require 'em-http'
require 'em-hiredis'
require 'em-http-request'

module MonitorTab
  module Pusher
    
    def self.redis
      redis_config = YAML.load_file(Rails.root.to_s + "/config/redis.yml")
      @redis ||= EM::Hiredis.connect(redis_config[ENV['RAILS_ENV']]['monitor_redis'])      
    end

    def self.next
      redis.blpop('monitor_notifications', 0).callback do |list, data|
        notification = JSON.parse(data)        
        channel = notification.delete('channel')
        campaign_id = notification.delete('campaign')
        caller_session_id = notification.delete('caller_session')
        type = notification.delete('type')
        event = notification.delete('event')
        self.send(type, channel, campaign_id, caller_session_id, event )
        EM.next_tick(&method(:next))   
      end      
    end
    
    def self.update_campaign_info(channel, campaign_id, caller_session_id, event)
      campaign = Campaign.find(campaign_id)
      num_remaining = campaign.all_voters.by_status('not called').count
      num_available = campaign.leads_available_now + num_remaining      
      info = RedisCaller.stats(campaign_id).merge(RedisCampaignCall.stats(campaign_id)).merge({available: num_available, remaining: num_remaining})      
      puts "ddddddddddd"
      puts info
      campaign_deferrable = ::Pusher[channel].trigger_async('update_campaign_info', info.merge!(event: event))
      campaign_deferrable.callback {}
      campaign_deferrable.errback { |error| puts error }                    
    end
    
    def self.update_caller_info(channel, campaign_id, caller_session_id, event)
      caller_deferrable = ::Pusher[channel].trigger_async('update_caller_info', {campaign_id: campaign_id, caller_session: caller_session_id, event: event})
      caller_deferrable.callback {}
      caller_deferrable.errback { |error| puts error }                          
    end
    
    def self.add_caller(channel, campaign_id, caller_session_id, event)
      caller = CallerSession.find(caller_session_id).caller
      caller.email = caller.identity_name
      caller_info = caller.info      
      caller_info.merge!({campaign_id: campaign_id, caller_session: caller_session_id, event: event})
      caller_deferrable = ::Pusher[channel].trigger_async('caller_connected', caller_info)
      caller_deferrable.callback {}
      caller_deferrable.errback { |error| puts error }                                
    end
    
    def self.remove_caller(channel, campaign_id, caller_session_id, event)
      caller_deferrable = ::Pusher[channel].trigger_async('caller_disconnected', {campaign_id: campaign_id, caller_session: caller_session_id, event: event})
      caller_deferrable.callback {}
      caller_deferrable.errback { |error| puts error }                                
    end
    
  end
end

EM.run do
  MonitorTab::Pusher.next
end