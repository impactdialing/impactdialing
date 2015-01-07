class Call < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallTwiml
  attr_accessible :id, :call_sid, :call_status, :caller, :state, :call_attempt, :questions, :notes, :answered_by, :campaign_type, :recording_url, :recording_duration

  has_one :call_attempt
  delegate :connect_call, :to => :call_attempt
  delegate :campaign, :to=> :call_attempt
  delegate :voter, :to=> :call_attempt
  delegate :household, :to => :call_attempt
  delegate :caller_session, :to=> :call_attempt
  delegate :end_caller_session, :to=> :call_attempt
  delegate :caller_session_key, :to=> :call_attempt
  delegate :enqueue_call_flow, :to=> :call_attempt
  delegate :update_recording!, :to => :call_attempt

private
  def stats
    @stats ||= Twillio::InflightStats.new(campaign)
  end

public
  def incoming_call(params={})
    campaign.number_not_ringing

    if campaign.predictive? and answered_by_human?
      caller_session_id = RedisOnHoldCaller.longest_waiting_caller(campaign.id)
      begin
        RescueRetryNotify.on ActiveRecord::StaleObjectError, 3 do
          loaded_caller_session = CallerSession.find_by_id_cached(caller_session_id)
          Twillio.set_attempt_in_progress(loaded_caller_session, call_attempt)
        end
      rescue ActiveRecord::StaleObjectError
        if caller_session_id
          RedisOnHoldCaller.add(campaign.id, caller_session_id)
        end
        return abandoned
      end
    end

    if answered_by_human? and call_in_progress?
      if caller_available?
        return connected(params)
      else
        return abandoned
      end
    else
      return call_answered_by_machine
    end
  end

  ##
  #
  ## params['voter_id']
  #
  # When params['voter_id'] is nil means voter will be selected
  # after call has been dispositioned. An integer voter_id
  # allows system-determined selection of voter before call
  # has been dispositioned.
  # Useful as an auto-select feature eg phones only.
  def connected(params)
    connect_call # CallAttempt
    enqueue_call_flow(VoterConnectedPusherJob, [call_attempt.caller_session_id, self.id])
    connected_twiml
  end

  def abandoned
    RedisCallFlow.push_to_abandoned_call_list(self.id)
    # todo: figure out how the fuck this got here.
    # call_attempt.redirect_caller
    abandoned_twiml
  end

  def call_answered_by_machine
    RedisCallFlow.push_to_processing_by_machine_call_hash(self.id)

    call_attempt.redirect_caller

    agent = AnsweringMachineAgent.new(call_attempt.household)

    twiml = Twilio::TwiML::Response.new do |r|
      if agent.leave_message?
        r.Play campaign.recording.file.url
      end
      r.Hangup
    end.text

    RedisCallFlow.record_message_drop_info(self.id, campaign.recording_id, 'automatic') if agent.leave_message?

    return twiml
  end

  def hungup
    enqueue_call_flow(EndRunningCallJob, [call_attempt.sid])
  end

  def disconnected
    unless cached_caller_session.nil?
      RedisCallFlow.push_to_disconnected_call_list(self.id, RedisCall.recording_duration(self.id), RedisCall.recording_url(self.id), cached_caller_session.caller_id);
      enqueue_call_flow(CallerPusherJob, [cached_caller_session.id, "publish_voter_disconnected"])
      RedisStatus.set_state_changed_time(call_attempt.campaign_id, "Wrap up", cached_caller_session.id)
    end
    disconnected_twiml
  end

  def call_ended(campaign_type, params={})
    unless caller_session.nil? # can be the case for transfers
      caller_session.publish_call_ended(params)
    end
    if call_did_not_connect?
      campaign.number_not_ringing
      RedisCallFlow.push_to_not_answered_call_list(self.id, redis_call_status)
    end

    if answered_by_machine?
      campaign.number_not_ringing
      RedisCallFlow.push_to_end_by_machine_call_list(self.id)
      # todo: verify caller is redirected when answering machine twiml is served at /incoming
      # if Campaign.preview_power_campaign?(campaign_type)  && redis_call_status == 'completed'
      #   call_attempt.redirect_caller
      # end
    end

    if Campaign.preview_power_campaign?(campaign_type)  && redis_call_status != 'completed'
      call_attempt.redirect_caller
    end

    if call_did_not_connect?
      RedisCall.delete(self.id)
    end
    call_ended_twiml
  end

  def wrapup_and_continue(params={})
    RedisCallFlow.push_to_wrapped_up_call_list(call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT, params[:voter_id])
    call_attempt.redirect_caller
    unless cached_caller_session.nil?
      RedisStatus.set_state_changed_time(call_attempt.campaign_id, "On hold", cached_caller_session.id)
    end
  end

  def wrapup_and_stop(params={})
    RedisCallFlow.push_to_wrapped_up_call_list(call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT, params[:voter_id])
    end_caller_session
  end

  def answered_by_machine?
    redis_answered_by == "machine"
  end

  def answered_by_human?
    !answered_by_machine?
  end

  def redis_answered_by
    RedisCall.answered_by(self.id)
  end

  def caller_available?
    cached_caller_session.present? and cached_caller_session.assigned_to_lead?
  end

  # todo: fix the naming of these methods & their internal calls to be consistent
  def answered_by_human_and_caller_available?
     answered_by_human? && redis_call_status == 'in-progress' &&
     !cached_caller_session.nil? && cached_caller_session.assigned_to_lead?
  end

  def answered_by_human_and_caller_not_available?
    answered_by_human?  && redis_call_status == 'in-progress' &&
    (cached_caller_session.nil? || !cached_caller_session.assigned_to_lead?)
  end

  def call_did_not_connect?
    ["no-answer", "busy", "failed"].include?(redis_call_status)
  end

  def call_connected?
    !call_did_not_connect?
  end

  def call_in_progress?
    redis_call_status == 'in-progress'
  end

  def redis_call_status
    RedisCall.call_status(self.id)
  end

  def cached_caller_session
    CallerSession.find_by_id_cached(call_attempt.caller_session_id)
  end

  def data_centre
    RedisCallerSession.datacentre(call_attempt.caller_session_id)
  end
end

# ## Schema Information
#
# Table name: `calls`
#
# ### Columns
#
# Name                      | Type               | Attributes
# ------------------------- | ------------------ | ---------------------------
# **`id`**                  | `integer`          | `not null, primary key`
# **`call_attempt_id`**     | `integer`          |
# **`state`**               | `string(255)`      |
# **`call_sid`**            | `string(255)`      |
# **`call_status`**         | `string(255)`      |
# **`answered_by`**         | `string(255)`      |
# **`recording_duration`**  | `integer`          |
# **`recording_url`**       | `string(255)`      |
# **`created_at`**          | `datetime`         |
# **`updated_at`**          | `datetime`         |
# **`questions`**           | `text`             |
# **`notes`**               | `text`             |
# **`all_states`**          | `text`             |
#
