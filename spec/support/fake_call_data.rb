module FakeCallData
  def add_voters(campaign, type=:voter, n=25)
    account = campaign.account

    list = build_and_import_list(type, n, {
      account: account,
      campaign: campaign
    })

    cache_voters(campaign.id, list.map(&:id), '1')

    list
  end

  def cache_voters(campaign_id, voter_ids, enabled='1')
    CallFlow::Jobs::CacheVoters.perform(campaign_id, voter_ids, enabled)
  end

  def process_recycle_bin(campaign)
    CallFlow::Jobs::ProcessRecycleBin.perform(campaign.id)
  end

  def process_presented(campaign)
    CallFlow::Jobs::ProcessPresentedVoters.perform(campaign.id)
  end

  def clean_dial_queue
    @dial_queue.clear
  end

  def cache_available_voters(campaign)
    dial_queue = CallFlow::DialQueue.new(campaign)
    dial_queue.clear
    cache_voters(campaign.id, campaign.all_voter_ids, '1')
    dial_queue
  end

  def add_callers(campaign, n=5)
    account = campaign.account

    build_and_import_list(:caller, n, {
      account: account,
      campaign: campaign
    })
  end

  # def twilio_posts_status_callback(status, household, caller)
  #   campaign = household.campaign
  #   caller ||= campaign.callers.sample
  #   twilio_params = {
  #     'CallStatus' => status,
  #     'To' => household.phone,
  #     'CallSid' => 'CA123',
  #     'AccountSid' => 'AC321'
  #   }
  #   dial_queue = CallFlow::DialQueue.new(campaign)
  #   dial_queue.dialed(twilio_params)
  # end

  def attach_call_attempt(type, household_or_voter, caller=nil)
    campaign = household_or_voter.campaign
    voter    = nil
    unless household_or_voter.is_a? Household
      voter     = household_or_voter
      household = household_or_voter.household 
    else
      household = household_or_voter
    end
    caller    ||= campaign.callers.sample

    call_attempt = create(type, {
      campaign: campaign,
      voter: voter,
      household: household,
      caller: caller,
      dialer_mode: campaign.type,
      call_end: 1.minute.from_now
    })
    call = create(:bare_call, call_attempt: call_attempt)

    # mimicing PersistCalls job
    case type.to_s
    when /past_recycle_time_failed_call_attempt|failed_call_attempt/
      household.failed!
    when /past_recycle_time_busy_call_attempt|busy_call_attempt/
      household.dialed(call_attempt)
      household.save!
    when /past_recycle_time_completed_call_attempt|completed_call_attempt/
      voter.try(:dispositioned, call_attempt)
      voter.save!
      household.dialed(call_attempt)
      household.save!
    when /past_recycle_time_machine_answered_call_attempt|machine_answered_call_attempt/
      household.dialed(call_attempt)
      household.save!
    else
      puts "Unknown CallAttempt factory type for FakeCallData#attach_call_attempt: #{type}"
    end

    yield call_attempt if block_given?

    # mimic_persist_calls(call_attempt, voter)

    call_attempt
  end

  def mimic_persist_calls(call_attempt, voter)
    household = call_attempt.household
    campaign  = call_attempt.campaign

    voter.try(:save!)
    
    household.dialed(call_attempt)
    household.save!
  end

  def add_call_attempts(campaign, n=35)
    if campaign.all_voters.empty?
      voters = add_voters(campaign)
    else
      voters = campaign.all_voters
      cache_voters(campaign.id, campaign.all_voter_ids, '1')
    end

    households = campaign.households

    if campaign.callers.empty?
      callers = add_callers(campaign)
    else
      callers = campaign.callers
    end
    voter = voters.sample
    call_attempts = build_and_import_list(:bare_call_attempt, n, {
      campaign: campaign,
      caller: callers.sample,
      voter: voter,
      household: voter.household
    })

    [voters, callers, call_attempts]
  end

  def call_and_leave_messages(dial_queue, voter_count, autodropped=0)
    voters = Voter.find(dial_queue.next(voter_count))

    voters.each do |voter|
      call_attempt = attach_call_attempt(:past_recycle_time_machine_answered_call_attempt, voter)
      call_attempt.update_recording!(autodropped)
    end
  end

  def create_campaign_with_script(type, account, campaign_attrs={})
    # Setup script, questions and possible responses
    script = create(:bare_script, {
      account: account
    })

    questions = build_and_import_list(:bare_question, 4, {
      script: script
    })

    build_and_import_list_for_each(questions, :bare_possible_response, 4) do |question|
      {
        question: question
      }
    end

    campaign = create(type, campaign_attrs.merge!({
      account: account,
      script: script
    }))

    [script, questions, campaign]
  end

  def create_campaign_with_answers(type, account, answer_count=12)
    script, questions, campaign    = create_campaign_with_script(type, account)
    voters, callers, call_attempts = add_call_attempts(campaign)

    build_and_import_sampled_list(:bare_answer, answer_count) do
      sampled_question = questions.sample
      sampled_call_attempt = call_attempts.sample

      {
        voter: sampled_call_attempt.voter,
        caller: sampled_call_attempt.caller,
        question: sampled_question,
        possible_response: sampled_question.possible_responses.sample,
        call_attempt: sampled_call_attempt,
        campaign: campaign
      }
    end

    {
      campaign: campaign,
      call_attempts: call_attempts
    }
  end

  def create_campaign_with_transfer_attempts(type, account)
    res           = create_campaign_with_answers(type, account)
    campaign      = res[:campaign]
    call_attempts = res[:call_attempts]

    transfers = build_and_import_list(:bare_transfer, 3, {
      script: campaign.script
    })

    build_and_import_sampled_list(:bare_transfer_attempt, 12) do
      sampled_transfer     = transfers.sample
      sampled_call_attempt = call_attempts.sample

      {
        campaign: campaign,
        transfer: sampled_transfer,
        call_attempt: sampled_call_attempt
      }
    end

    {
      campaign: campaign
    }
  end
end