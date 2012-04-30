module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected
      event_hash = campaign.voter_connected_event(self.call)
      caller_session.publish_async(event_hash[:event], event_hash[:data])
    end    
    
    def publish_voter_disconnected
      caller_session.publish_async('voter_disconnected',{})
    end
    
    def publish_monitor_response_submitted
      return if campaign.account.moderators.active.empty?
      Moderator.publish_event(campaign, 'voter_response_submitted', {:caller_session_id => caller_session.id, :campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
    end
    
    def publish_monitor_voter_connected 
      return if campaign.account.moderators.active.empty?
      Moderator.publish_event(campaign, 'voter_connected', {:caller_session_id => caller_session.id, :campaign_id => campaign.id, :caller_id => caller_session.caller.id})
    end
    
    def publish_monitor_voter_disconnected
      return if campaign.account.moderators.active.empty?
      Moderator.publish_event(campaign, 'voter_disconnected', {:caller_session_id => caller_session.id,:campaign_id => campaign.id, :caller_id => caller_session.caller.id, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})      
    end
    
    def publish_moderator_dials_in_progress
      return if campaign.account.moderators.active.empty?
      Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})            
    end 
    
    
      
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end