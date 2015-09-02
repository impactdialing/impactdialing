##
# Used when a Campaign is set to phones only.
#
class PhonesOnlyCallerSession < CallerSession
  def callin_choice
    read_choice_twiml
  end

  def read_choice(params={})
    return instructions_options_twiml if pound_selected?(params)
    return ready_to_call if star_selected?(params)
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
    begin
      house = campaign.next_in_dial_queue
    rescue CallFlow::DialQueue::EmptyHousehold => e
      Rails.logger.error "#{e.class}: #{e.message}"
      source = "ac-#{self.campaign.account_id}.ca-#{self.campaign.id}.cs-#{self.id}"
      name   = "phones_only.dial_queue.empty_household"
      ImpactPlatform::Metrics.count(name, 1, source)
      return twiml_redirect_to_next_call # have Twilio retry this request
    end

    return campaign_out_of_phone_numbers_twiml if house.nil?

    voter = house[:leads].first
    if preview?
      choosing_voter_to_dial_twiml(voter['uuid'], house[:phone], voter['first_name'], voter['last_name'])
    elsif power?
      choosing_voter_and_dial_twiml(voter['uuid'], house[:phone], voter['first_name'], voter['last_name'])
    end
  end

  def dial(voter_id, phone)
    start_conference
    enqueue_call_flow(PreviewPowerDialJob, [self.id, phone])
    conference_started_phones_only_twiml(voter_id, phone)
  end

  def conference_started_phones_only_power(params)
    voter_id = params[:voter_id]
    phone    = params[:phone]
    dial(voter_id, phone)
  end

  def conference_started_phones_only_preview(params)
    voter_id = params[:voter_id]
    phone    = params[:phone]

    if pound_selected?(params)
      return skip_voter_twiml
    elsif star_selected?(params)
      return dial(voter_id, phone)
    else
      return choosing_voter_to_dial_twiml(voter_id, phone)
    end
  end

  def conference_started_phones_only_predictive
    start_conference
    conference_started_phones_only_predictive_twiml
  end

  def gather_response(params)
    return read_next_question_twiml(params) if call_answered?(params)
    wrapup_call(params)
  end

  def redis_survey_response_from_digits(params)
    possible_responses = RedisPossibleResponse.possible_responses(params[:question_id])
    possible_responses.detect{|possible_response| possible_response['keypad'] == params[:Digits].to_i} || {}
  end

  def submit_response(params)
    selected_response = redis_survey_response_from_digits(params)
    dialed_call.collect_response(params, selected_response) 

    return disconnected_twiml if disconnected?
    return wrapup_call(params) if skip_all_questions?(params)
    redirect_to_next_question_twiml(params)
  end

  def wrapup_call(params)
    voter_id = params.try(:[], :voter_id)
    voter_id ||= dialed_call.storage[:lead_uuid]
    wrapup_call_attempt

    if dialed_call.present?
      # normalize survey responses for persistence
      survey_responses = {
        question: {},
        lead: {id: voter_id}
      }
      dialed_call_data = dialed_call.storage.attributes
      dialed_call_data.each do |key, val|
        next unless key =~ /\Aquestion_\d+/
        _,question_id = key.split '_'
        survey_responses[:question][question_id] = val
      end
      dialed_call.dispositioned(survey_responses)
    end

    wrapup_call_twiml
  end

  def next_call
    ready_to_call
  end

  def skip_voter
    skip_voter_twiml
  end

  def skip_all_questions?(params)
    params[:Digits] == "999"
  end

  def wrapup_call_attempt
    RedisStatus.set_state_changed_time(campaign_id, "On hold", self.id)
  end

  def more_questions_to_be_answered?(params)
    RedisQuestion.more_questions_to_be_answered?(script_id, params[:question_number])
  end

  def lead_connected_to_caller?
    dialed_call.present? and (dialed_call.completed? or dialed_call.in_progress?) and dialed_call.answered_by_human?
  end

  def call_answered?(params)
    lead_connected_to_caller? && more_questions_to_be_answered?(params)
  end

  def star_selected?(params)
    params[:Digits] == "*"
  end

  def pound_selected?(params)
    params[:Digits] == "#"
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
