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
        campaign_info = @redis.hgetall "moderator:#{campaign_id}"
        ::Pusher[channel].trigger_async('update_campaign_info', campaign_info)
        EM.next_tick(&method(:next))
      end
    end
  end
end

EM.run do
  MonitorTab::Pusher.next
end