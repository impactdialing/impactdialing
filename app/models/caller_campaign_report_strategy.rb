require 'octopus'

class CallerCampaignReportStrategy < CampaignReportStrategy

private
  def with_slave(&block)
    Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)) do
      yield
    end
  end

public
  def csv_header
    header_fields = [manipulate_header_fields, @selected_custom_voter_fields, "Caller", "Status", "Time Call Dialed", "Time Call Answered", "Time Call Ended", "Call Duration (seconds)", "Time Transfer Started", "Time Transfer Ended", "Transfer Duration (minutes)"]

    if @mode == CampaignReportStrategy::Mode::PER_LEAD
      header_fields << "Attempts"
      header_fields << "Message Left"
    elsif @mode == CampaignReportStrategy::Mode::PER_DIAL
      header_fields << "Message Left"
    end
    header_fields.concat(["Recording", Question.question_texts(@question_ids) , Note.note_texts(@note_ids)])
    header_fields.flatten.compact
  end

  def manipulate_header_fields
    manipulated_fields = []
    headers = {"custom_id" => "ID", "last_name"=> "Last name", "first_name"=>  "First name", "middle_name"=> "Middle name",
    "address"=> "Address", "city"=>  "City", "state"=> "State", "zip_code"=>  "Zip code", "country"=> "Country", "phone"=>"Phone"}
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
    @replica_connection.execute(Caller.where(id: ids).select([:id, :name, :username]).to_sql).each(as: :hash).each_with_object({}) do |hash, memo|
      memo[hash['id']] = if hash['name'].blank?
                           hash['username'].blank? ? "" : hash['username']
                         else
                           hash['name']
                         end
    end
  end

  def get_transfer_attempts(call_attempts)
    ids = call_attempts.map{|ca| ca['id'] }
    @replica_connection.execute(TransferAttempt.where(call_attempt_id: ids).select([:id, :call_attempt_id, :tStartTime, :tEndTime, :tDuration]).to_sql).each(as: :hash).each_with_object({}) do |hash, memo|
      memo[hash['call_attempt_id']] = hash
    end
  end

  def get_call_attempts_number(household_ids)
    query = CallAttempt.where(household_id: household_ids).
      select("household_id, count(id) as cnt, max(id) as last_id").group(:household_id).to_sql
    @replica_connection.execute(query).each(as: :hash).each_with_object({}) do |hash, memo|
      memo[hash['household_id']] = {
        cnt: hash['cnt'],
        last_id: hash['last_id']
      }
    end
  end

  def get_voicemail_history(household_ids)
    query = CallAttempt.where(household_id: household_ids).
      select("household_id, recording_id, recording_delivered_manually").group(:household_id).to_sql
    @replica_connection.execute(query).each(as: :hash).each_with_object({}) do |hash, memo|
      memo[hash['household_id']] = {
        message_left_text: message_left_text(hash['recording_id'], hash['recording_delivered_manually'])
      }
    end
  end

  def get_possible_responses
    Hash[*@replica_connection.execute(PossibleResponse.select("id, value").where(question_id: @question_ids).to_sql).to_a.flatten]
  end

  def get_custom_voter_field_values(voter_ids)
    query = CustomVoterField.where(account_id: @campaign.account_id, name: @selected_custom_voter_fields.try(:compact)).
      joins(:custom_voter_field_values).
      where(custom_voter_field_values: {voter_id: voter_ids}).
      group(:voter_id, :name).select([:name, :value, :voter_id]).to_sql
    OctopusConnection.connection(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)).execute(query).each(as: :hash).each_with_object({}) do |hash, memo|
      memo[hash['voter_id']] ||= {}
      memo[hash['voter_id']][hash['name']] = hash['value']
    end
  end

  def selected_fields(voter, selection = nil)
    unless selection
      [voter['phone']] 
    else
      selected = selection.select{ |field| Voter::UPLOAD_FIELDS.include?(field) }
      unless voter['id']
        # maintain correct number of columns
        [voter['phone']].fill(nil, 1, selected.size - 1)
      else
        selected.map{ |field| voter[field] }
      end
    end
  end

  def selected_custom_fields(voter, selection, values)
    unless selection
      []
    else
      unless voter['id']
        # maintain correct number of columns
        [].fill(nil, 0, selection.size)
      else
        values ||= {}
        selection.map{ |field| values[field] }
      end
    end
  end

  def csv_for(voter, values)
    voter_fields  = selected_fields(voter, @selected_voter_fields.try(:compact))
    custom_fields = selected_custom_fields(voter, @selected_custom_voter_fields, values)

    [*voter_fields, *custom_fields, [nil, "Not Dialed","","","","", [], []]]
  end

  def process_attempts(attempts)
    voter_ids     = []
    attempt_ids   = []
    household_ids = []

    attempts.each do |a|
      voter_ids     << a['voter_id']
      attempt_ids   << a['id']
      household_ids << a['household_id']
    end

    conn       = OctopusConnection.connection(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2))
    households = conn.execute(Household.where(id: household_ids).to_sql).each(as: :hash).each_with_object({}){ |x, memo| memo[x['id']] = x }
    voters     = conn.execute(Voter.where(id: voter_ids).to_sql).each(as: :hash).each_with_object({}) do |x, memo|
      x['phone']    = households[x['household_id']]['phone']
      memo[x['id']] = x
    end
    voter_field_values = get_custom_voter_field_values(voter_ids)
    answers            = get_answers(attempt_ids)
    note_responses     = get_note_responses(attempt_ids)
    caller_names       = get_callers_names(attempts)
    attempt_numbers    = get_call_attempts_number(household_ids)
    voicemail_history  = get_voicemail_history(household_ids)
    transfer_attempts  = get_transfer_attempts(attempts)

    attempts.each do |attempt|
      voter_id     = attempt['voter_id']
      attempt_id   = attempt['id']
      household_id = attempt['household_id']
      voter        = voter_id.present? ? voters[voter_id] : {'phone' => households[household_id]['phone']}
      data         = csv_for(voter, voter_field_values[voter_id])
      voter        = voters[voter_id]
      data[-1]     = call_attempt_details(attempt, answers[attempt_id], note_responses[attempt_id], caller_names, attempt_numbers, @possible_responses, transfer_attempts[attempt_id], voter, voicemail_history)

      @csv << data.flatten
    end
  end

  def process_households(households)
    data               = {}
    call_attempt_ids   = []
    household_ids      = households.map(&:id)
    voter_ids          = households.map(&:voters).flatten.map(&:id)
    attempt_numbers    = get_call_attempts_number(household_ids)
    voter_field_values = get_custom_voter_field_values(voter_ids)
    voicemail_history  = get_voicemail_history(household_ids)

    households.each do |household|
      household.voters.each do |voter|
        voter_data     = voter.attributes.merge('phone' => household.phone)
        data[voter.id] = csv_for(voter_data, voter_field_values[voter.id])
        call_attempt_ids << attempt_numbers[household['id']][:last_id] if attempt_numbers[household['id']]
      end
    end

    conn              = OctopusConnection.connection(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2))
    attempts          = conn.execute(CallAttempt.where(id: call_attempt_ids.compact).includes(:transfer_attempt).to_sql).each(as: :hash)
    answers           = get_answers(call_attempt_ids)
    note_responses    = get_note_responses(call_attempt_ids)
    caller_names      = get_callers_names(attempts)
    transfer_attempts = get_transfer_attempts(attempts)

    attempts.each do |attempt|
      household = households.find{ |household| household.id == attempt['household_id'] }
      household.voters.each do |voter|
        data[voter.id][-1] = call_attempt_details(attempt, answers[attempt['id']], note_responses[attempt['id']], caller_names, attempt_numbers, @possible_responses, transfer_attempts[attempt['id']], voter, voicemail_history)
      end
    end

    data.values.each do |o|
      @csv << o.flatten
    end
  end

  def download_by_lead(query, start = 1)
    with_slave do
      @possible_responses = get_possible_responses

      query.order('call_attempts.id').find_in_batches({
        batch_size: 5000,
        start: start
      }) do |households|
        process_households(households)
      end
    end
  end

  def household_query
    Household.where(campaign_id: @campaign.id).
      includes(:call_attempts, :voters).
      joins(:call_attempts)
  end

  def download_all_voters_lead
    with_slave do
      first_household = household_query.order('households.id').first
      download_by_lead(household_query, start_position(first_household))
    end
  end

  def download_for_date_range_lead
    with_slave do
      query = household_query.where(
        'call_attempts.created_at >= ? AND call_attempts.created_at <= ?',
        @from_date,
        @to_date
      )
      first_household = query.order('households.id').first
      download_by_lead(query, start_position(first_household))
    end
  end

  def call_attempt_query
    CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_created_id)').
      for_campaign(@campaign).
      order('created_at').
      includes(:answers, :note_responses, :transfer_attempt)
  end

  def download_by_dial(query, start = 1)
    with_slave do
      @possible_responses = get_possible_responses
      call_attempt_query.find_in_hashes({
        batch_size: 5000,
        start: start,
        shard: OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)
      }) do |attempts|
        process_attempts(attempts)
      end
    end
  end

  def download_all_voters_dial
    with_slave do
      first_attempt = CallAttempt.for_campaign(@campaign).order('id').first
      download_by_dial(call_attempt_query, start_position(first_attempt))
    end
  end

  def download_for_date_range_dial
    with_slave do
      first_attempt = CallAttempt.for_campaign(@campaign).between(@from_date, @to_date).order('id').first
      query         = call_attempt_query.between(@from_date, @to_date)
      download_by_dial(query, start_position(first_attempt))
    end
  end

  def call_attempt_details(call_attempt, answers, note_responses, caller_names, attempt_numbers, possible_responses, transfer_attempt={}, voter={}, voicemail_history={})
    if [CallAttempt::Status::RINGING, CallAttempt::Status::READY].include?(call_attempt['status'])
      [nil, "Not Dialed","","","","", "", [], []]
    else
      [call_attempt_info(call_attempt, caller_names, attempt_numbers, transfer_attempt, voter, voicemail_history), PossibleResponse.possible_response_text(@question_ids, answers, possible_responses), NoteResponse.response_texts(@note_ids, note_responses)].flatten
    end
  end

  def start_position(obj)
    obj.nil? ? 0 : obj.id
  end

end
