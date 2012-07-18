module ModeratorEvent
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def voter_connected(campaign, caller_session)
      redis = Redis.current
      redis.pipelined do
        ModeratorCampaign.increment_on_call(campaign.id, 1)
        ModeratorCampaign.decrement_on_hold(campaign.id, 1)
        ModeratorCampaign.increment_live_lines(campaign.id, 1)                            
      end
      redis.publish :monitor_event, "#{campaign_id}"
    end
    
    def incoming_call(campaign)
      redis = Redis.current
      redis.pipelined do      
        ModeratorCampaign.decrement_ringing_lines(campaign.id, 1)        
      end
      redis.publish :monitor_event, "#{campaign_id}"
    end
    
    
    def voter_disconnected(campaign, caller_session)
      redis = Redis.current
      redis.pipelined do
        ModeratorCampaign.decrement_on_call(campaign.id, 1)
        ModeratorCampaign.increment_wrapup(campaign.id, 1)
        ModeratorCampaign.decrement_live_lines(campaign.id, 1)
      end
      redis.publish :monitor_event, "#{campaign_id}"      
    end
    
    def voter_response_submitted(campaign, caller_session)
      redis = Redis.current
      redis.pipelined do
        ModeratorCampaign.decrement_wrapup(campaign.id, 1)
        ModeratorCampaign.increment_on_hold(campaign.id, 1)
      end
      redis.publish :monitor_event, "#{campaign_id}"            
    end
    
    def caller_disconnected(campaign, caller_session)
      redis = Redis.current
      ModeratorCampaign.decrement_callers_logged_in(campaign.id, 1)
      redis.publish :monitor_event, "#{campaign_id}"
    end    

  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
  
end