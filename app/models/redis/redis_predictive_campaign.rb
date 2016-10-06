require 'redis/hash_key'
require 'redis/set'

class RedisPredictiveCampaign
  include Redis::Objects

  def self.redis_connection_pool
      $redis_dialer_connection
  end

  def self.add(campaign_id, type)
    # campaign_set = Redis::Set.new("running_campaigns", $redis_dialer_connection)
    campaign_set = redis_connection_pool.with{|conn| Redis::Set.new("running_campaigns", conn)}
    # campaign_set = Redis::Set.new("running_campaigns", $redis_dialer_connection)
    campaign_set << campaign_id if Campaign.predictive_campaign?(type)
  end

  def self.remove(campaign_id, type)
    campaign_set = redis_connection_pool.with{|conn| Redis::Set.new("running_campaigns", conn)}
    # campaign_set = Redis::Set.new("running_campaigns", $redis_dialer_connection)
    campaign_set.delete(campaign_id) if Campaign.predictive_campaign?(type)
  end


  def self.running_campaigns
    campaign_set = redis_connection_pool.with{|conn| Redis::Set.new("running_campaigns", conn)}
    # campaign_set = Redis::Set.new("running_campaigns", $redis_dialer_connection)
    campaign_set.members
  end


end