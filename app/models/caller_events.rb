module CallerEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
            
    def publish_start_calling
      if state == "initial"
        publish_sync('start_calling', {caller_session_id: id})
      end
    end    
    
    def publish_voter_connected(call_id)            
      call = Call.find(call_id)
      unless caller.is_phones_only? 
        event_hash = campaign.voter_connected_event(call)        
        Pusher[session_key].trigger!(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
      end
    end    
    
    
    def publish_voter_disconnected
      unless caller.is_phones_only?      
        Pusher[session_key].trigger!("voter_disconnected", {})
      end  
    end
    
    def publish_voter_event_moderator
      Moderator.active_moderators(campaign).each do |moderator|
        Pusher[moderator.session].trigger!('voter_event', {caller_session_id:  self.id, campaign_id:  campaign.id, caller_id:  caller.id, call_status: attempt_in_progress.try(:status)})      
      end              
    end
    
    def publish_caller_conference_started
      unless caller.is_phones_only? 
        event_hash = campaign.caller_conference_started_event(voter_in_progress.try(:id))     
        Pusher[session_key].trigger!(event_hash[:event], event_hash[:data].merge!(:dialer => campaign.type))
     end      
    end
    
    def publish_caller_conference_started_moderator
      Moderator.active_moderators(campaign).each do |moderator|
        Pusher[moderator.session].trigger!('voter_event', {caller_session_id:  id, campaign_id:  campaign.id, caller_id:  caller.id, call_status: attempt_in_progress.try(:status)})      
      end                      
    end
    
    def publish_caller_conference_started_moderator_dials
      Moderator.active_moderators(campaign).each do |moderator|
        Pusher[moderator.session].trigger!('update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
      end                      
    end
    
    
    def publish_calling_voter
      Pusher[session_key].trigger!('calling_voter', {}) unless caller.is_phones_only? 
    end
    
    def publish_calling_voter_moderator
      Moderator.active_moderators(campaign).each do |moderator|
        Pusher[moderator.session].trigger!('update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
      end              
    end
    
    def publish_caller_disconnected      
      Pusher[session_key].trigger!("caller_disconnected", {}) unless caller.is_phones_only?
    end   
    
    def publish_moderator_caller_reassigned_to_campaign(old_campaign)
      return if campaign.account.moderators.active.empty?
      Moderator.publish_event(campaign, "caller_re_assigned_to_campaign", {:caller_session_id => id, :caller_id => caller.id, :campaign_fields => {:id => campaign.id, :campaign_name => campaign.name, :callers_logged_in => campaign.caller_sessions.on_call.size,
        :voters_count => Voter.remaining_voters_count_for('campaign_id', campaign.id), :dials_in_progress => campaign.call_attempts.not_wrapped_up.size }, :old_campaign_id => old_campaign.id,:no_of_callers_logged_in_old_campaign => old_campaign.caller_sessions.on_call.size})          
    end
    
    
    def publish_moderator_conference_started
      Moderator.active_moderators(campaign).each do |moderator|
        Pusher[moderator.session].trigger!('voter_event', {caller_session_id:  id, campaign_id:  campaign.id, caller_id:  caller.id, call_status: attempt_in_progress.try(:status)})      
      end                    
    end
    
    def caller_connected_to_campaign
      return if campaign.account.moderators.active.empty?
      caller.email = caller.identity_name
      caller_info = caller.info
      data = caller_info.merge(:campaign_name => campaign.name, :session_id => self.id, :campaign_fields => {:id => campaign.id,
        :callers_logged_in => campaign.caller_sessions.on_call.size+1,
        :voters_count => campaign.voters_count("not called", false), :dials_in_progress => campaign.call_attempts.not_wrapped_up.size },
        :campaign_ids => caller.account.campaigns.active.collect{|c| c.id}, :campaign_names => caller.account.campaigns.active.collect{|c| c.name},:current_campaign_id => campaign.id)
        
        Moderator.active_moderators(campaign).each do |moderator|
          Pusher[moderator.session].trigger!("caller_session_started", data)
        end
    end
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end