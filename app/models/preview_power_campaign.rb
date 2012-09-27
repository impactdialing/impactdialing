module PreviewPowerCampaign
  
  def next_voter_in_dial_queue(current_voter_id = nil)
    begin
      voter = all_voters.priority_voters.first
      voter||= all_voters.scheduled.first
      voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.not_skipped.where("voters.id > #{current_voter_id}").first unless current_voter_id.blank?
      voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.not_skipped.first
      voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.where("voters.id != #{current_voter_id}").first unless current_voter_id.blank?
      voter||= all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.first    
      update_voter_status_to_ready(voter)
    rescue ActiveRecord::StaleObjectError
      retry
    end
    RedisVoter.load_voter_info(voter.id, voter) unless voter.nil?
    voter
  end  
  
  def redirect_campaign_reassigned(caller_session)
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Call.redirect(caller_session.sid, phones_only_caller_index_url(:host => Settings.host, :port => Settings.port, session_id: caller_session.id, :campaign_reassigned => true))    
  end
  
  def update_voter_status_to_ready(voter)
    voter.update_attributes(status: CallAttempt::Status::READY) unless voter.nil?        
  end
  
    
  def caller_conference_started_event(current_voter_id)
    next_voter = next_voter_in_dial_queue(current_voter_id)
    {event: 'conference_started', data: next_voter.nil? ? {} : next_voter.info}                     
  end
  
  def voter_connected_event(call)
    {event: 'voter_connected', data: {call_id:  call.id}}
  end
  
  def call_answered_machine_event(call_attempt)    
    next_voter = next_voter_in_dial_queue(call_attempt.voter.id)
    {event: 'dial_next_voter', data: next_voter.nil? ? {} : next_voter.info}                         
  end
  
  
  
end