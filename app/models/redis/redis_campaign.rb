require 'redis/hash_key'
require 'redis/set'

class RedisCampaign
  include Redis::Objects
  
  def self.load_campaign(campaign_id, campaign)
    campaign(campaign_id).bulk_set(campaign.attributes.to_options)        
  end
  
  def self.campaign(campaign_id)
    Redis::HashKey.new("campaign:#{campaign_id}", $redis_call_flow_connection)    
  end
  
  def self.add_running_predictive_campaign(campaign_id, type)
    campaign_set = Redis::Set.new("running_campaigns", $redis_call_flow_connection)    
    campaign_set << campaign_id if type == Campaign::Type::PREDICTIVE
  end
  
  def self.remove_running_predictive_campaign(campaign_id)
    campaign_set = Redis::Set.new("running_campaigns", $redis_call_flow_connection)    
    campaign_set.delete(campaign_id)
  end
  
  
  def self.running_campaigns
    campaign_set = Redis::Set.new("running_campaigns", $redis_call_flow_connection)
    campaign_set.members
  end
  
  def self.read_campaign(campaign_id)
    campaign(campaign_id).all
  end
  
  def self.call_status_use_recordings(campaign_id)
    RedisCampaign.read_campaign(campaign_id)['use_recordings'] == "true" ? CallAttempt::Status::VOICEMAIL : CallAttempt::Status::HANGUP
  end
    
end