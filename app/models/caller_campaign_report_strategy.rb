class CallerCampaignReportStrategy < CampaignReportStrategy
  
  def csv_header
    header_fields = [@selected_voter_fields, @selected_custom_voter_fields, "Caller", "Status", "Time Dialed","Time Answered", "Time Ended" ]    
    header_fields << "Attempts" if @mode == CampaignReportStrategy::Mode::PER_LEAD
    header_fields.concat(["Recording", Question.question_texts(@question_ids) , Note.note_texts(@note_ids)])
    header_fields.flatten.compact
  end
  
  def process_dial(attempts)
   return Proc.new {|attempts| attempts.each { |attempt| @csv << csv_for_call_attempt(attempt, question_ids, note_ids) } }
  end
  
  def process_voters(voters)
    return Proc.new {|attempts| voters.each { |voter| @csv << csv_for(voter, question_ids, note_ids) } }
  end
 
  def download_all_voters_lead
    @campaign.all_voters.find_in_batches(:batch_size => 100) { |voters| process_voters(voters)}    
  end
  
  def download_all_voters_dial
    @campaign.call_attempts.find_in_batches(:batch_size => 100) { |attempts| process_dial(attempts) }
  end
  
  def download_for_date_range_lead
     @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).find_in_batches(:batch_size => 100) { |voters| process_voters(voters)}        
  end
  
  def download_for_date_range_dial
    @campaign.call_attempts.between(@from_date, @to_date).find_in_batches(:batch_size => 100) { |attempts| process_dial(attempts) }
  end
  
  def call_attempt_details(call_attempt, voter)
    answers = call_attempt.answers.for_questions(@question_ids).order('question_id')
    note_responses = call_attempt.note_responses.for_notes(@note_ids).order('note_id')    
    [call_attempt_info(call_attempt), PossibleResponse.possible_response_text(@question_ids, answers), NoteResponse.response_texts(@note_ids, note_responses)].flatten    
  end
  
  def call_details(voter, question_ids, note_ids)
    last_attempt = voter.call_attempts.last
    if last_attempt
      call_attempt_details(last_attempt, voter)
    else
      [nil, "Not Dialed","","","","", [], [] ]
    end
  end
  
end