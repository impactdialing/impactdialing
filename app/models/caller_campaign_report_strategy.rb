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
    @replica_connection.execute(Answer.where(question_id: @question_ids, call_attempt_id: attempt_ids).order(:question_id).to_sql).each(as: :hash).each_with_object({}) do |x, memo|
      memo[x['call_attempt_id']] ||= []
      memo[x['call_attempt_id']] << x
    end
  end

  def get_note_responses(attempt_ids)
    @replica_connection.execute(NoteResponse.where(call_attempt_id: attempt_ids, note_id: @note_ids).order(:note_id).to_sql).each(as: :hash).each_with_object({}) do |x, memo|
      memo[x['call_attempt_id']] ||= []
      memo[x['call_attempt_id']] << x
    end
  end

  def get_callers_names(attempts)
    ids = attempts.map { |a| a['caller_id'] }.uniq
    @replica_connection.execute(Caller.where(id: ids).select([:id, :name, :email]).to_sql).each(as: :hash).each_with_object({}) do |hash, memo|
      memo[hash['id']] = if hash['name'].blank?
                           hash['email'].blank? ? "" : hash['email']
                         else
                           hash['name']
                         end
    end
  end
  
  def get_custom_voter_field_values(voter_ids)
    query = CustomVoterField.where(account_id: @campaign.account_id, name: @selected_custom_voter_fields.try(:compact)).
      joins(:custom_voter_field_values).
      where(custom_voter_field_values: {voter_id: voter_ids}).
      group(:voter_id, :name).select([:name, :value, :voter_id]).to_sql
    OctopusConnection.connection(:read_slave1).execute(query).each(as: :hash).each_with_object({}) do |hash, memo|
      memo[hash['voter_id']] ||= {} 
      memo[hash['voter_id']][hash['name']] = hash['value'] 
    end
  end

  def get_call_attempts_number(voter_ids)
    query = CallAttempt.where(voter_id: voter_ids).
      select("voter_id, count(id) as cnt, max(id) as last_id").group(:voter_id).to_sql
    @replica_connection.execute(query).each(as: :hash).each_with_object({}) do |hash, memo|
      memo[hash['voter_id']] = {cnt: hash['cnt'], last_id: hash['last_id']}
    end
  end

  def get_possible_responses
    Hash[*@replica_connection.execute(PossibleResponse.select("id, value").where(question_id: @question_ids).to_sql).to_a.flatten]
  end


  def selected_fields(voter, selection = nil)
    return [voter['Phone']] unless selection
    selection.select { |field| Voter::UPLOAD_FIELDS.include?(field) }.map { |field| voter[field] }
  end

  def selected_custom_fields(voter, selection, values)
    return [] unless selection
    values ||= {}
    selection.map { |field| values[field] }
  end

  def csv_for(voter, values)
    voter_fields = selected_fields(voter, @selected_voter_fields.try(:compact))
    custom_fields = selected_custom_fields(voter, @selected_custom_voter_fields, values)
    [*voter_fields, *custom_fields, [nil, "Not Dialed","","","","", [], []]]
  end
  
  def process_voters(voters)
    data = {}
    call_attempt_ids = []
    voter_ids = voters.map { |v| v['id'] }
    attempt_numbers = get_call_attempts_number(voter_ids)
    voter_field_values = get_custom_voter_field_values(voter_ids)
    voters.each do |voter|
      data[voter['id']] = csv_for(voter, voter_field_values[voter['id']])
      call_attempt_ids << attempt_numbers[voter['id']][:last_id] if attempt_numbers[voter['id']]
    end
    attempts = CallAttempt.connection.execute(CallAttempt.where(id: call_attempt_ids.compact).to_sql).each(as: :hash)
    answers = get_answers(call_attempt_ids)
    note_responses = get_note_responses(call_attempt_ids)
    caller_names = get_callers_names(attempts) 
    attempts.each do |a|
      data[a['voter_id']][-1] = call_attempt_details(a, answers[a['id']], note_responses[a['id']], caller_names, attempt_numbers, @possible_responses)
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
    voter_field_values = get_custom_voter_field_values(voter_ids)

    answers = get_answers(attempt_ids)
    note_responses = get_note_responses(attempt_ids)
    caller_names = get_callers_names(attempts) 
    attempt_numbers = get_call_attempts_number(voter_ids)

    attempts.each do |attempt|
      voter_id = attempt['voter_id']
      attempt_id = attempt['id']
      data = csv_for(voters[voter_id], voter_field_values[voter_id])
      data[-1] = call_attempt_details(attempt, answers[attempt_id], note_responses[attempt_id], caller_names, attempt_numbers, @possible_responses)
      @csv << data.flatten
    end
  end

  def download_all_voters_lead
    Octopus.using(:read_slave1) do
      first_voter = Voter.by_campaign(@campaign).order('id').first
      @possible_responses = get_possible_responses
      Voter.by_campaign(@campaign).order('last_call_attempt_time').find_in_hashes(:batch_size => 100, start: start_position(first_voter), shard: :read_slave1) do |voters|
        process_voters(voters)
      end    
    end
  end
  
  def download_all_voters_dial
    Octopus.using(:read_slave1) do
      first_attempt = CallAttempt.for_campaign(@campaign).order('id').first
      @possible_responses = get_possible_responses
      CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id)').for_campaign(@campaign).order('created_at').includes(:answers, :note_responses).find_in_hashes(:batch_size => 100, start: start_position(first_attempt), shard: :read_slave1) do |attempts|
        process_attempts(attempts)
      end
    end
  end
  
  def download_for_date_range_lead
    Octopus.using(:read_slave1) do
      first_voter = Voter.by_campaign(@campaign).last_call_attempt_within(@from_date, @to_date).order('id').first
      @possible_responses = get_possible_responses
      Voter.by_campaign(@campaign).last_call_attempt_within(@from_date, @to_date).order('created_at').find_in_hashes(:batch_size => 100, start: start_position(first_voter), shard: :read_slave1) do |voters|
        process_voters(voters)
      end
    end
  end
  
  def download_for_date_range_dial
    Octopus.using(:read_slave1) do
      first_attempt = CallAttempt.for_campaign(@campaign).between(@from_date, @to_date).order('id').first
      @possible_responses = get_possible_responses
      CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id)').for_campaign(@campaign).between(@from_date, @to_date).order('created_at').includes(:answers, :note_responses).find_in_batches(:batch_size => 100, start: start_position(first_attempt)) do |attempts|
        process_attempts(attempts)
      end 
    end
  end
  
  def call_attempt_details(call_attempt, answers, note_responses, caller_names, attempt_numbers, possible_responses)
    if [CallAttempt::Status::RINGING, CallAttempt::Status::READY].include?(call_attempt['status'])
      [nil, "Not Dialed","","","","", [], []]
    else
      [call_attempt_info(call_attempt, caller_names, attempt_numbers), PossibleResponse.possible_response_text(@question_ids, answers, possible_responses), NoteResponse.response_texts(@note_ids, note_responses)].flatten    
    end
  end
  
  def start_position(obj)
    obj.nil? ? 0 : obj.id
  end
  
end
