require 'octopus'

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

  def get_answers(attempt_ids)
    Answer.connection.execute(Answer.where(question_id: @question_ids, call_attempt_id: attempt_ids).order(:question_id).to_sql).each(as: :hash).each_with_object({}) do |x, memo|
      memo[x['call_attempt_id']] ||= []
      memo[x['call_attempt_id']] << x
    end
  end

  def get_note_responses(attempt_ids)
    NoteResponse.connection.execute(NoteResponse.where(call_attempt_id: attempt_ids, note_id: @note_ids).order(:note_id).to_sql).each(as: :hash).each_with_object({}) do |x, memo|
      memo[x['call_attempt_id']] ||= []
      memo[x['call_attempt_id']] << x
    end
  end
  
  def process_voters(voters)
    data = {}
    call_attempt_ids = []
    voters.each do |voter|
      data[voter['id']] = csv_for(voter)
      call_attempt_ids << CallAttempt.where(voter_id: voter['id']).last
    end
    attempts = CallAttempt.connection.execute(CallAttempt.where(id: call_attempt_ids.compact).to_sql).each(as: :hash)
    answers = get_answers(call_attempt_ids)
    note_responses = get_note_responses(call_attempt_ids)
    attempts.each do |a|
      data[a['voter_id']][-1] = call_attempt_details(a, answers[a['id']], note_responses[a['id']])
    end
    data.values.each do |o|
      @csv << o.flatten
    end
  end
 
  def process_attempts(attempts)
    voter_ids = []
    attempt_ids = []
    attempts.each do |a|
      voter_ids << a['voter_id']
      attempt_ids << a['id']
    end

    conn = OctopusConnection.connection(:read_slave1)
    voters = conn.execute(Voter.where(id: voter_ids).to_sql).each(as: :hash).each_with_object({}) { |x, memo| memo[x['id']] = x }

    answers = get_answers(attempt_ids)
    note_responses = get_note_responses(attempt_ids)

    attempts.each do |attempt|
      data = csv_for(voters[attempt['voter_id']])
      data[-1] = call_attempt_details(attempt, answers[attempt['id']], note_responses[attempt['id']])
      @csv << data.flatten
    end
  end

  def download_all_voters_lead
    Octopus.using(:read_slave1) do
      first_voter = Voter.by_campaign(@campaign).order('last_call_attempt_time').first
      Voter.by_campaign(@campaign).order('last_call_attempt_time').find_in_hashes(:batch_size => 100, start: start_position(first_voter), shard: :read_slave1) do |voters|
        process_voters(voters)
      end    
    end
  end
  
  def download_all_voters_dial
    Octopus.using(:read_slave1) do
      first_attempt = CallAttempt.for_campaign(@campaign).order('created_at').first
      CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id)').for_campaign(@campaign).order('created_at').includes(:answers, :note_responses).find_in_hashes(:batch_size => 100, start: start_position(first_attempt), shard: :read_slave1) do |attempts|
        process_attempts(attempts)
      end
    end
  end
  
  def download_for_date_range_lead
    Octopus.using(:read_slave1) do
      first_voter = Voter.by_campaign(@campaign).last_call_attempt_within(@from_date, @to_date).order('created_at').first
      Voter.by_campaign(@campaign).last_call_attempt_within(@from_date, @to_date).order('created_at').find_in_hashes(:batch_size => 100, start: start_position(first_voter), shard: :read_slave1) do |voters|
        process_voters(voters)
      end
    end
  end
  
  def download_for_date_range_dial
    Octopus.using(:read_slave1) do
      first_attempt = CallAttempt.for_campaign(@campaign).between(@from_date, @to_date).order('created_at').first
      CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id)').for_campaign(@campaign).between(@from_date, @to_date).order('created_at').includes(:answers, :note_responses).find_in_batches(:batch_size => 100, start: start_position(first_attempt)) do |attempts|
        process_attempts(attempts)
      end 
    end
  end
  
  def call_attempt_details(call_attempt, answers, note_responses)
    if [CallAttempt::Status::RINGING, CallAttempt::Status::READY].include?(call_attempt['status'])
      [nil, "Not Dialed","","","","", [], []]
    else
      [call_attempt_info(call_attempt), PossibleResponse.possible_response_text(@question_ids, answers), NoteResponse.response_texts(@note_ids, note_responses)].flatten    
    end
  end
  
  def start_position(obj)
    obj.nil? ? 0 : obj.id
  end
  
end
