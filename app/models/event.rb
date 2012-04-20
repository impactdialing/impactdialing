module Event
  
  module ClassMethods
  end
  
  module InstanceMethods
    
    def publish_voter_connected
      # call_attempt.caller_session.publish('voter_connected', {:attempt_id => call_attempt.id, :voter => call_attempt.voter.info})
      # Moderator.publish_event(campaign, 'voter_connected', {:caller_session_id => session.id, :campaign_id => campaign.id, :caller_id => session.caller.id})
    end      
    
    def publish_call_answered_by_machine
      # next_voter = call_attempt.campaign.next_voter_in_dial_queue(call_attempt.voter.id)
      # call_attempt.caller_session.publish('voter_push', next_voter ? next_voter.info : {})
      # call_attempt.caller_session.publish('conference_started', {})
    end
    
    def publish_abandoned_call
          # Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})    
    end
    
    def publish_voter_disconnected
      Pusher[caller_session.session_key].trigger('voter_disconnected', {:attempt_id => self.id, :voter => self.voter.info})
      Moderator.publish_event(campaign, 'voter_disconnected', {:caller_session_id => caller_session.id,:campaign_id => campaign.id, :caller_id => caller_session.caller.id, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})      
    end
    
    def publish_unanswered_call_ended
      next_voter = self.campaign.next_voter_in_dial_queue(voter.id) 
      caller_session.publish('voter_push',next_voter.nil? ? {} : next_voter.info)               
      Moderator.publish_event(campaign, 'update_dials_in_progress', {:campaign_id => campaign.id, :dials_in_progress => campaign.call_attempts.not_wrapped_up.size, :voters_remaining => Voter.remaining_voters_count_for('campaign_id', campaign.id)})
    end
    
    def publish_conference_started
      Moderator.caller_connected_to_campaign(@caller, @caller.campaign, @session)
      if campaign.type == Campaign::Type::PREVIEW || campaign.type == Campaign::Type::PROGRESSIVE
        publish('conference_started', {}) 
      else
        publish('caller_connected_dialer', {})
      end
      
    end
    
    
    
    
    
  end
  
  def self.included(receiver)
    receiver.extend         ClassMethods
    receiver.send :include, InstanceMethods
  end
  
end