class CallerCampaignReportStrategy < CampaignReportStrategy
  
  def csv_header
    header_fields = [manipulate_header_fields, @selected_custom_voter_fields, "Caller", "Status", "Time Dialed", "Time Answered", "Time Ended" ]    
    header_fields << "Attempts" if @mode == CampaignReportStrategy::Mode::PER_LEAD
    header_fields.concat(["Recording", Question.question_texts(@question_ids) , Note.note_texts(@note_ids)])
    header_fields.flatten.compact
  end
  
  def manipulate_header_fields
    manipulated_fields = []
    headers = {"CustomID" => "ID", "LastName"=> "Last name", "FirstName"=>  "First name", "MiddleName"=> "Middle name",
    "address"=> "Address", "city"=>  "City", "state"=> "State", "zip_code"=>  "Zip code", "country"=> "Country"} 
    @selected_voter_fields.each do |voter_field|
      if headers.has_key?(voter_field)
        manipulated_fields << headers[voter_field]
      else
        manipulated_fields << voter_field
      end
    end
    manipulated_fields 
  end
  
 
  def download_all_voters_lead
    Octopus.using(:read_slave1) do
      @campaign.all_voters.order('last_call_attempt_time').find_in_batches(:batch_size => 100) do |voters|
        voters.each {|voter| @csv << csv_for(voter)}
      end    
    end
  end
  
  def download_all_voters_dial
    Octopus.using(:read_slave1) do
      @campaign.call_attempts.order('created_at').find_in_batches(:batch_size => 100) do |attempts| 
        attempts.each { |attempt| @csv << csv_for_call_attempt(attempt) } 
      end
    end
  end
  
  def download_for_date_range_lead
    Octopus.using(:read_slave1) do
      @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).order('created_at').find_in_batches(:batch_size => 100) do |voters|
        voters.each do |voter|
           @csv << csv_for(voter)
        end
      end
    end
  end
  
  def download_for_date_range_dial
    Octopus.using(:read_slave1) do
      @campaign.call_attempts.between(@from_date, @to_date).order('created_at').find_in_batches(:batch_size => 100) do |attempts|
        attempts.each { |attempt| @csv << csv_for_call_attempt(attempt) } 
      end 
    end
  end
  
  def call_attempt_details(call_attempt, voter)
    if [CallAttempt::Status::RINGING, CallAttempt::Status::READY ].include?(call_attempt.status)
      [nil, "Not Dialed","","","","", [], [] ]
    else
      answers = call_attempt.answers.for_questions(@question_ids).order('question_id')
      note_responses = call_attempt.note_responses.for_notes(@note_ids).order('note_id')    
      [call_attempt_info(call_attempt), PossibleResponse.possible_response_text(@question_ids, answers), NoteResponse.response_texts(@note_ids, note_responses)].flatten    
    end
  end
  
  def call_details(voter)
    last_attempt = voter.call_attempts.last
    if last_attempt
      call_attempt_details(last_attempt, voter)
    else
      [nil, "Not Dialed","","","","", [], [] ]
    end
  end
  
end