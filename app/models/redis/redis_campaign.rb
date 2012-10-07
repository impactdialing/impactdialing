require 'redis/hash_key'
require 'redis/set'

class RedisCampaign
  include Redis::Objects
  
  
  def self.add_running_predictive_campaign(campaign_id, type)
    campaign_set = Redis::Set.new("running_campaigns", $redis_call_flow_connection)    
    campaign_set << campaign_id if Campaign.predictive_campaign?(type)
  end
  
  def self.remove_running_predictive_campaign(campaign_id)
    campaign_set = Redis::Set.new("running_campaigns", $redis_call_flow_connection)    
    campaign_set.delete(campaign_id)
  end
  
  
  def self.running_campaigns
    campaign_set = Redis::Set.new("running_campaigns", $redis_call_flow_connection)
    campaign_set.members
  end  
    
end