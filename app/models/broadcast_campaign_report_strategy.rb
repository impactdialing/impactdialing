class BroadcastCampaignReportStrategy < CampaignReportStrategy
  
  def csv_header
    [@selected_voter_fields, @selected_custom_voter_fields, "Status", @campaign.script.robo_recordings.collect { |rec| rec.name }].flatten.compact
  end
  
  def call_attempt_details(call_attempt, voter, question_ids, note_ids)
    [call_attempt.status, (call_attempt.call_responses.collect { |call_response| call_response.recording_response.try(:response) } if call_attempt.call_responses.size > 0)].flatten
  end

  def call_details(voter, question_ids, note_ids)
    last_attempt = voter.call_attempts.last
    details = last_attempt ? [last_attempt.status, (last_attempt.call_responses.collect { |call_response| call_response.recording_response.try(:response) } if last_attempt.call_responses.size > 0)].flatten : ['Not Dialed']
    details
  end
  
  
end