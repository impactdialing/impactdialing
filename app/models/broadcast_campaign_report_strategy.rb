class BroadcastCampaignReportStrategy < CampaignReportStrategy
  
  def csv_header
    [@selected_voter_fields, @selected_custom_voter_fields, "Status", @campaign.script.robo_recordings.collect { |rec| rec.name }].flatten.compact  
  end
  
  def download_all_voters_lead
    @campaign.all_voters.order('last_call_attempt_time').find_in_batches(:batch_size => 100) do |voters|
      voters.each {|voter| @csv << csv_for(voter)}
    end    
  end
  
  def download_all_voters_dial
    @campaign.call_attempts.order('created_at').find_in_batches(:batch_size => 100) do |attempts| 
      attempts.each { |attempt| @csv << csv_for_call_attempt(attempt) } 
    end
  end
  
  def download_for_date_range_lead
    @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).order('created_at').find_in_batches(:batch_size => 100) do |voters|
      voters.each {|voter| @csv << csv_for(voter)}
    end
  end
  
  def download_for_date_range_dial
    @campaign.call_attempts.between(@from_date, @to_date).order('created_at').find_in_batches(:batch_size => 100) do |attempts|
      attempts.each { |attempt| @csv << csv_for_call_attempt(attempt) } 
    end 
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