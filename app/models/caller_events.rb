module CallerEvents
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_async(event, data)
      EM.run {
        deferrable = Pusher[session_key].trigger_async(event, data.merge!(:dialer => campaign.type))
        deferrable.callback { 
          }
        deferrable.errback { |error|
        }
      }
         
    end
    
    def publish_sync(event, data)
      Pusher[session_key].trigger(event, data.merge!(:dialer => self.campaign.type))
    end
    
    
    
    def publish_start_calling
      publish_sync('start_calling', {caller_session_id: id}) if state == 'initial'                     
    end    
    
    def publish_caller_conference_started
      event_hash = campaign.caller_conference_started_event
      publish_async(event_hash[:event], event_hash[:data])                     
    end
    
    def publish_calling_voter
      publish_async('calling_voter', {})
    end
    
    def publish_caller_disconnected
      # Moderator.publish_event(campaign, "caller_disconnected",{:caller_session_id => id, :caller_id => caller.id, :campaign_id => campaign.id, :campaign_active => campaign.callers_log_in?,
      #         :no_of_callers_logged_in => campaign.caller_sessions.on_call.size})
      
      publish("caller_disconnected",{})    
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
        
    
    
    
    
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end