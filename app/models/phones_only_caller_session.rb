class PhonesOnlyCallerSession < CallerSession


  def callin_choice
    read_choice_twiml
  end

  def read_choice
    return instructions_options_twiml if pound_selected?
    return ready_to_call_twiml if star_selected?
    callin_choice
  end

  def ready_to_call(callerdc)
    return conference_started_phones_only_predictive(callerdc) if  predictive?
    return choosing_voter_to_dial if  preview?
    return choosing_voter_and_dial if  power?
  end

  def choosing_voter_to_dial
    select_voter(voter_in_progress)
    choosing_voter_to_dial_twiml
  end

  def choosing_voter_and_dial
    select_voter(voter_in_progress)
    choosing_voter_and_dial_twiml
  end

  def conference_started_phones_only_power
    start_conference
    enqueue_call_flow(PreviewPowerDialJob, [self.id, voter_in_progress.id])
    conference_started_phones_only_twiml
  end


  def conference_started_phones_only_preview
    if pound_selected?
      return skip_voter
    end
    if star_selected?
      start_conference
      enqueue_call_flow(PreviewPowerDialJob, [self.id, voter_in_progress.id])
      return conference_started_phones_only_twiml
    end
    choosing_voter_to_dial_twiml
  end

  def conference_started_phones_only_predictive(callerdc)
    start_conference(callerdc)
    conference_started_phones_only_predictive_twiml
  end


  def skip_voter
    voter_in_progress.skip
    skip_voter_twiml
  end


  def gather_response
    return read_next_question_twiml if call_answered?
    wrapup_call
  end

  def submit_response
    RedisPhonesOnlyAnswer.push_to_list(voter_in_progress.id, self.id, redis_digit, redis_question_id) if voter_in_progress
    return disconnected_twiml if disconnected?
    return wrapup_call if skip_all_questions?
    voter_response_twiml
  end

  def next_question
    return read_next_question_twiml if more_questions_to_be_answered?
    wrapup_call
  end

  def wrapup_call
    wrapup_call_attempt
    wrapup_call_twiml
  end

  def next_call
    ready_to_call(RedisCallerSession.datacentre(self.id))
  end


  def skip_all_questions?
    redis_digit == "999"
  end

  def wrapup_call_attempt
    RedisStatus.set_state_changed_time(campaign_id, "On hold", self.id)
    unless attempt_in_progress.nil?
      RedisCallFlow.push_to_wrapped_up_call_list(attempt_in_progress.id, CallerSession::CallerType::PHONE);
    end
  end



  def more_questions_to_be_answered?
    RedisQuestion.more_questions_to_be_answered?(script_id, redis_question_number)
  end

  def call_answered?
    attempt_in_progress.try(:connecttime) != nil && more_questions_to_be_answered?
  end


  def select_voter(old_voter)
    voter = campaign.next_voter_in_dial_queue(old_voter.try(:[], 'id'))
    unless voter.nil?
      self.update_attributes(voter_in_progress: voter)
    end
    voter
  end


  def star_selected?
    redis_digit == "*"
  end


  def pound_selected?
    redis_digit == "#"
  end

  def preview?
    campaign.type == Campaign::Type::PREVIEW
  end


  def power?
    campaign.type == Campaign::Type::PROGRESSIVE
  end

  def predictive?
    campaign.type == Campaign::Type::PREDICTIVE
  end

  def preview_campaign?
    campaign.type != Campaign::Type::Preview
  end

  def redis_digit
    RedisCallerSession.digit(self.id)
  end

  def redis_question_number
    RedisCallerSession.question_number(self.id).try(:to_i) || 0
  end

  def redis_question_id
    RedisCallerSession.question_id(self.id)
  end

  def handleReassignedCampaign
    super
  end

end