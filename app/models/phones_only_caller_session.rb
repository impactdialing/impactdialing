##
# Used when a Campaign is set to phones only.
#
class PhonesOnlyCallerSession < CallerSession


  def callin_choice
    read_choice_twiml
  end

  def read_choice
    return instructions_options_twiml if pound_selected?
    return ready_to_call if star_selected?
    read_choice_twiml
  end

  def ready_to_call
    # CalculateDialsJob determines whether dialing is allowed
    return conference_started_phones_only_predictive if predictive?

    # abort call before loading voters
    return abort_dial_twiml if !fit_to_dial?

    return setup_call
  end

  def setup_call
    house = campaign.next_in_dial_queue
    return campaign_out_of_phone_numbers_twiml if house.nil?

    voter = house[:voters].first[:fields]
    if preview?
      choosing_voter_to_dial_twiml(voter['id'], house[:phone], voter['first_name'], voter['last_name'])
    elsif power?
      choosing_voter_and_dial_twiml(voter['id'], house[:phone], voter['first_name'], voter['last_name'])
    end
  end

  def dial(voter_id, phone)
    start_conference
    enqueue_call_flow(PreviewPowerDialJob, [self.id, phone])
    conference_started_phones_only_twiml(voter_id, phone)
  end

  def conference_started_phones_only_power(voter_id, phone)
    dial(voter_id, phone)
  end

  def conference_started_phones_only_preview(voter_id, phone)
    if pound_selected?
      return skip_voter_twiml
    elsif star_selected?
      return dial(voter_id, phone)
    else
      return choosing_voter_to_dial_twiml(voter_id, phone)
    end
  end

  def conference_started_phones_only_predictive
    start_conference
    conference_started_phones_only_predictive_twiml
  end

  def gather_response(voter_id)
    return read_next_question_twiml(voter_id) if call_answered?
    wrapup_call(voter_id)
  end

  def submit_response(voter_id)
    voter_id ||= attempt_in_progress.voter_id
    household_id = attempt_in_progress.household_id
    RedisPhonesOnlyAnswer.push_to_list(voter_id, household_id, self.id, redis_digit, redis_question_id)
    return disconnected_twiml if disconnected?
    return wrapup_call(voter_id) if skip_all_questions?
    redirect_to_next_question_twiml(voter_id)
  end

  def wrapup_call(voter_id)
    wrapup_call_attempt(voter_id)

    wrapup_call_twiml
  end

  def next_call
    ready_to_call
  end

  def skip_voter
    skip_voter_twiml
  end

  def skip_all_questions?
    redis_digit == "999"
  end

  def wrapup_call_attempt(voter_id)
    RedisStatus.set_state_changed_time(campaign_id, "On hold", self.id)
    unless attempt_in_progress.nil?
      RedisCallFlow.push_to_wrapped_up_call_list(attempt_in_progress.id, CallerSession::CallerType::PHONE, voter_id)
    end
  end

  def more_questions_to_be_answered?
    RedisQuestion.more_questions_to_be_answered?(script_id, redis_question_number)
  end

  def call_answered?
    attempt_in_progress.try(:connecttime) != nil && more_questions_to_be_answered?
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
    campaign.type == Campaign::Type::POWER
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

# ## Schema Information
#
# Table name: `caller_sessions`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`caller_id`**             | `integer`          |
# **`campaign_id`**           | `integer`          |
# **`endtime`**               | `datetime`         |
# **`starttime`**             | `datetime`         |
# **`sid`**                   | `string(255)`      |
# **`available_for_call`**    | `boolean`          | `default(FALSE)`
# **`voter_in_progress_id`**  | `integer`          |
# **`created_at`**            | `datetime`         |
# **`updated_at`**            | `datetime`         |
# **`on_call`**               | `boolean`          | `default(FALSE)`
# **`caller_number`**         | `string(255)`      |
# **`tCallSegmentSid`**       | `string(255)`      |
# **`tAccountSid`**           | `string(255)`      |
# **`tCalled`**               | `string(255)`      |
# **`tCaller`**               | `string(255)`      |
# **`tPhoneNumberSid`**       | `string(255)`      |
# **`tStatus`**               | `string(255)`      |
# **`tDuration`**             | `integer`          |
# **`tFlags`**                | `integer`          |
# **`tStartTime`**            | `datetime`         |
# **`tEndTime`**              | `datetime`         |
# **`tPrice`**                | `float`            |
# **`attempt_in_progress`**   | `integer`          |
# **`session_key`**           | `string(255)`      |
# **`state`**                 | `string(255)`      |
# **`type`**                  | `string(255)`      |
# **`digit`**                 | `string(255)`      |
# **`debited`**               | `boolean`          | `default(FALSE)`
# **`question_id`**           | `integer`          |
# **`caller_type`**           | `string(255)`      |
# **`question_number`**       | `integer`          |
# **`script_id`**             | `integer`          |
# **`reassign_campaign`**     | `string(255)`      | `default("no")`
#
# ### Indexes
#
# * `index_caller_sessions_debit`:
#     * **`debited`**
#     * **`caller_type`**
#     * **`tStartTime`**
#     * **`tEndTime`**
#     * **`tDuration`**
# * `index_caller_sessions_on_caller_id`:
#     * **`caller_id`**
# * `index_caller_sessions_on_campaign_id`:
#     * **`campaign_id`**
# * `index_caller_sessions_on_sid`:
#     * **`sid`**
# * `index_callers_on_call_group_by_campaign`:
#     * **`campaign_id`**
#     * **`on_call`**
# * `index_state_caller_sessions`:
#     * **`state`**
#
