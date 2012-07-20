class ModeratorEvent
  
  def self.create_job(campaign_id, event)
    Sidekiq::Client.push('queue' => 'monitor_worker', 'class' => ModeratorJob, 'args' => [campaign_id, event, Time.now])
  end
  
    
  def incoming_call(campaign)
    redis = Redis.current
    redis.pipelined do      
      ModeratorCampaign.decrement_ringing_lines(campaign.id, 1)        
    end
  end
    
    
  def voter_connected(campaign)
    redis = Redis.current
    redis.pipelined do
      ModeratorCampaign.increment_on_call(campaign.id, 1)
      ModeratorCampaign.decrement_on_hold(campaign.id, 1)
      ModeratorCampaign.increment_live_lines(campaign.id, 1)                            
    end
  end
    
    
    
  def voter_disconnected(campaign)
    redis = Redis.current
    redis.pipelined do
      ModeratorCampaign.decrement_on_call(campaign.id, 1)
      ModeratorCampaign.increment_wrapup(campaign.id, 1)
      ModeratorCampaign.decrement_live_lines(campaign.id, 1)
    end
  end
    
  def voter_response_submitted(campaign)
    redis = Redis.current
    redis.pipelined do
      ModeratorCampaign.decrement_wrapup(campaign.id, 1)
      ModeratorCampaign.increment_on_hold(campaign.id, 1)
    end
  end
    
  def caller_disconnected(campaign)
    redis = Redis.current
    ModeratorCampaign.decrement_callers_logged_in(campaign.id, 1)
  end    
  
end