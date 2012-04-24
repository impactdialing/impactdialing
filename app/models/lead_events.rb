module LeadEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
        
    
    def publish_voter_connected
      event_hash = campaign.voter_connected_event(call_attempt)
      caller_session.publish(event_hash[:event], event_hash[:data])
      # Moderator.publish_event(campaign, 'voter_connected', {:caller_session_id => session.id, :campaign_id => campaign.id, :caller_id => session.caller.id})
    end    
    
    def publish_voter_disconnected
      caller_session.publish('voter_disconnected',{})
      # Moderator.publish_event(campaign, 'voter_disconnected', {:caller_session_id => caller_session.id,:campaign_id => campaign.id, :caller_id => caller_session.caller.id, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})      
    end
      
    
    def publish_call_answered_by_machine
      event_hash = campaign.call_answered_machine_event(call_attempt)
      caller_session.publish(event_hash[:event], event_hash[:data]) if caller_session
    end
    
    
    def publish_abandoned_call
          # Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})    
    end
    
    
    def publish_unanswered_call_ended
      # next_voter = self.campaign.next_voter_in_dial_queue(voter.id) 
      # caller_session.publish('voter_push',next_voter.nil? ? {} : next_voter.info)               
      # Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
    end
    
    def publish_conference_started
      # Moderator.caller_connected_to_campaign(@caller, @caller.campaign, @session)
      # if campaign.type == Campaign::Type::PREVIEW || campaign.type == Campaign::Type::PROGRESSIVE
      #   publish('conference_started', {}) 
      # else
      #   publish('caller_connected_dialer', {})
      # end
      # 
    end
    
    def publish_continue_calling
      # Moderator.publish_event(call_attempt.campaign, 'voter_response_submitted', {:caller_session_id => params[:caller_session], :campaign_id => call_attempt.campaign.id, :dials_in_progress => call_attempt.campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', call_attempt.campaign.id)})
      # next_voter = call_attempt.campaign.next_voter_in_dial_queue(call_attempt.voter.id)
      # call_attempt.caller_session.publish("voter_push", next_voter ? next_voter.info : {})
      # call_attempt.caller_session.publish("predictive_successful_voter_response", {})
    end
    
    def publish_caller_reassignes_to_campaign_for_monitor
      # Moderator.publish_event(campaign, "caller_re_assigned_to_campaign", {:caller_session_id => id, :caller_id => caller.id, :campaign_fields => {:id => campaign.id, :campaign_name => campaign.name, :callers_logged_in => campaign.caller_sessions.on_call.size,
      #   :voters_count => Voter.remaining_voters_count_for('campaign_id', campaign.id), :dials_in_progress => campaign.call_attempts.not_wrapped_up.size }, :old_campaign_id => old_campaign.id,:no_of_callers_logged_in_old_campaign => old_campaign.caller_sessions.on_call.size})      
    end
    
    def publish_caller_reassigned_to_campaign
      # publish_caller_reassignes_to_campaign_for_monitor
      # next_voter = caller.campaign.next_voter_in_dial_queue
      # self.publish("caller_re_assigned_to_campaign",{:campaign_name => caller.campaign.name, :campaign_id => caller.campaign.id, :script => caller.campaign.script.try(:script)}.merge!(next_voter ? next_voter.info : {}))      
    end
    
    def publish_caller_conference_started
      event_hash = campaign.caller_conference_started
      publish(event_hash[:event], event_hash[:data])                     
    end
    
    
    
    
    
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end