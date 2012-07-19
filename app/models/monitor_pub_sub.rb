require 'redis'
class MonitorPubSub 
  
  def initialize
   @redis = Redis.current    
  end
  

  def push_to_monitor_screen
    @redis.psubscribe(:monitor_event ) do |on|
      on.pmessage do |pattern, event, message|     
        campaign = Campaign.find(message)
        Moderator.active_moderators(campaign).each do|moderator|
          begin
            Pusher[moderator.session].trigger!('update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
          rescue Exception => e
            Rails.logger.error "Pusher exception: #{e}"    
          end
        end         
      end
   end
   
  end
  
end