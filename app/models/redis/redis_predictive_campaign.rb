require 'redis/hash_key'
require 'redis/set'

class RedisPredictiveCampaign
  include Redis::Objects
  
  
  def self.add(campaign_id, type)
    campaign_set = Redis::Set.new("running_campaigns", $redis_dialer_connection)    
    campaign_set << campaign_id if Campaign.predictive_campaign?(type)
  end
  
  def self.remove(campaign_id, type)
    campaign_set = Redis::Set.new("running_campaigns", $redis_dialer_connection)    
    campaign_set.delete(campaign_id) if Campaign.predictive_campaign?(type)
  end
  
  
  def self.running_campaigns
    campaign_set = Redis::Set.new("running_campaigns", $redis_dialer_connection)
    campaign_set.members
  end  
  
  def self.set_datacentres_used(campaign_id, datacentre)
    campaign_set = Redis::Set.new("data_centre:#{campaign_id}", $redis_dialer_connection)
    campaign_set << datacentre
  end
  
  def self.data_centres(campaign_id)
    campaign_set = Redis::Set.new("data_centre:#{campaign_id}", $redis_dialer_connection)
    campaign_set.members.join(",")
  end
    
end