module PreviewPowerCampaign
  
  def next_voter_in_dial_queue(current_voter_id = nil)
    voter = all_voters.priority_voters.first
    voter||= all_voters.scheduled.first
    voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.not_skipped.where("voters.id > #{current_voter_id}").first unless current_voter_id.blank?
    voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.not_skipped.first
    voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.where("voters.id != #{current_voter_id}").first unless current_voter_id.blank?
    voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.first
    unless voter.nil?
      begin
        voter.update_attributes(status: CallAttempt::Status::READY)
      rescue ActiveRecord::StaleObjectError
        next_voter_in_dial_queue(voter.id)
      end
    end
    voter
  end
  
    
  def caller_conference_started_event
    next_voter = next_voter_in_dial_queue
    {event: 'conference_started', data: next_voter.nil? ? {} : next_voter.info}                     
  end
  
  def voter_connected_event(call_attempt)
    {event: 'voter_connected', data: {attempt_id:  call_attempt.id}}
  end
  
  def call_answered_machine_event(call_attempt)    
    next_voter = next_voter_in_dial_queue(call_attempt.voter.id)
    {event: 'dial_next_voter', data: next_voter.nil? ? {} : next_voter.info}                         
  end
  
  
  
end