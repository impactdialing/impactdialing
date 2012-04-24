class PreviewCallAttempt < CallAttempt
  
  def process_call_answered_by_machine
    super
    caller_session.update_attribute(:voter_in_progress, nil)
    next_voter = campaign.next_voter_in_dial_queue(voter.id)
    caller_session.publish('voter_push', next_voter ? next_voter.info : {})
    caller_session.publish('conference_started', {})    
  end
  
  
end