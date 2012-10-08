class MonitorCampaignJob
  include Sidekiq::Worker
  sidekiq_options({ unique: :all, forever: true})
  
  def perform(campaign_id)
    sessions = MonitorSession.sessions_last_hour(campaign_id)
    unless sessions.blank?
      info = campaign_info(campaign_id)
      sessions.each do |session|
        push_campaign_info(session, info)        
      end      
    end
    
  end
  
  def campaign_info(campaign_id)
    campaign = Campaign.find(campaign_id)
    num_remaining = campaign.all_voters.by_status('not called').count
    num_available = campaign.leads_available_now + num_remaining      
    RedisCaller.stats(campaign_id).merge(RedisCampaignCall.stats(campaign_id)).merge({available: num_available, remaining: num_remaining})             
  end
  
  def push_campaign_info(session, info)
    ::Pusher[session].trigger('update_campaign_info', info.merge!(event: event))
  end
  
end

