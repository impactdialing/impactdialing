class CallFlow::Call::Dialed < CallFlow::Call::Lead
  attr_reader :twiml_flag, :recording_url, :record_calls, :conference_name

private
  def self.storage_key(rest_response)
    CallFlow::Call::Storage.key(rest_response['account_sid'], rest_response['sid'], namespace)
  end

  def self.keys(campaign, rest_response)
    [
      Twillio::InflightStats.key(campaign),
      self.storage_key(rest_response)
    ]
  end

  def self.lua_options(campaign, rest_response, optional_properties)
    {
      keys: keys(campaign, rest_response),
      argv: [
        params_for_create(rest_response).to_json,
        optional_properties.to_json,
        campaign.predictive? ? 1 : 0
      ]
    }
  end

  def params_for_update(params)
    whitelist = self.class.params_for_create(params)
    [:campaign_id, :campaign_type, :phone].each do |key|
      whitelist.merge!(key => params[key]) if params[key].present?
    end
    whitelist
  end

  def handle_failed_dial(campaign, params)
    source      = [
      "ac-#{campaign.account_id}",
      "ca-#{campaign.id}",
      "sid-#{params[:CallSid]}",
      "code-#{params['ErrorCode']}"
    ]
    metric_name = "twiml.http_error"
    ImpactPlatform::Metrics.count(metric_name, 1, source.join('.'))
    @twiml_flag = :hangup
  end
  def handle_successful_dial(campaign, caller_session_record, params)
    if campaign.predictive? and answered_by_human?(params)
      Twillio.predictive_dial_answered(caller_session_record, params)
    end

    if answered_by_human?(params) and call_in_progress?(params)
      attempt_connection(campaign, caller_session_record, params)
    else
      call_answered_by_machine(campaign, caller_session_record, params)
    end
  end
  def attempt_connection(campaign, caller_session_record, params)
    if caller_session_record.on_call? and (not caller_session_record.available_for_call?)
      RedisStatus.set_state_changed_time(campaign.id, "On call", caller_session_record.id)
      VoterConnectedPusherJob.add_to_queue(caller_session_record.id, params[:CallSid], params[:phone])
      caller_session_call.dialed_call_sid = params[:CallSid]
      update_history(:caller_and_lead_connected)
      @twiml_flag   = :connect
      @record_calls = campaign.account.record_calls.to_s
    else
      @twiml_flag = :hangup
    end
  end
  def call_answered_by_machine(campaign, caller_session_record, params)
    RedirectCallerJob.add_to_queue(caller_session_record.id)
    answering_machine_agent = AnsweringMachineAgent.new(campaign, storage[:phone])

    if answering_machine_agent.leave_message?
      @twiml_flag    = :leave_message
      @recording_url = campaign.recording.file.url
      answering_machine_agent.record_message_drop
      storage.save({
        mapped_status: CallAttempt::Status::VOICEMAIL,
        recording_id: campaign.recording.id,
        recording_delivered_manually: 0
      })
    else
      @twiml_flag = :hangup
    end
  end
  def answered_by_machine?(params)
    params[:AnsweredBy] == 'machine'
  end
  def call_in_progress?(params)
    params[:CallStatus] == 'in-progress'
  end

public
  def self.create(campaign, rest_response, optional_properties={})
    account_sid = rest_response['account_sid']
    sid         = rest_response['sid']
    validate!(account_sid, sid)

    opts = lua_options(campaign, rest_response, optional_properties)
    Wolverine.call_flow.dialed(opts)
    if campaign.class.to_s !~ /(Preview|Power|Predictive)/ or campaign.new_record?
      raise ArgumentError, "CallFlow::Call::Dialed received new or unknown campaign: #{campaign.class}"
    end

    self.new(account_sid, sid)
  end

  def self.namespace
    'dialed'
  end

  def namespace
    self.class.namespace
  end

  def answered_by_human?(params={})
    params = params.empty? ? storage : params
    not answered_by_machine?(params)
  end

  def caller_session_from_sid
    @caller_session ||= ::CallerSession.where(sid: self.caller_session_sid).first
  end

  def caller_session_from_id(campaign, params)
    @caller_session ||= if campaign.predictive? and answered_by_human?(params)
                          caller_session_id = RedisOnHoldCaller.longest_waiting_caller(campaign.id)
                          ::CallerSession.find(caller_session_id)
                        end
  end

  def caller_session_call
    @caller_session_call ||= CallFlow::CallerSession.new(account_sid, caller_session_sid)
  end
  
  def completed?
    storage[:status] == 'completed'
  end

  def in_progress?
    storage[:status] == 'in-progress'
  end

  def answered(campaign, params)
    # todo: make following writes atomic
    update_history(:answered)
    campaign.number_not_ringing
    storage.save(params_for_update(params))

    caller_session_record = caller_session_from_id(campaign, params) || caller_session_from_sid

    @conference_name = caller_session_record.session_key

    unless params['ErrorCode'] and params['ErrorUrl']
      handle_successful_dial(campaign, caller_session_record, params)
    else
      handle_failed_dial(campaign, params)
    end
  end

  def disconnected(params)
    storage.save(params_for_update(params))
    if caller_session_from_sid.present?
      RedisStatus.set_state_changed_time(caller_session_from_sid.campaign_id, "Wrap up", caller_session_from_sid.id)
    end
    caller_session.emit('publish_voter_disconnected')
  end

  def completed(campaign, params)
    storage.save(params_for_update(params))

    caller_session.try(:emit, 'publish_call_ended', params)

    if state_missed?(:answered)
      campaign.number_not_ringing

      unless campaign.predictive?
        caller_session.redirect_to_hold
      end
    end

    if state_missed?(:caller_and_lead_connected)
      CallFlow::Jobs::Persistence.perform_async('Completed', account_sid, sid)
    end
  end

  def dispositioned?
    completed? and answered_by_human? and state.visited?(:caller_and_lead_connected)
  end

  def manual_message_dropped(recording)
    storage.save({
      mapped_status: CallAttempt::Status::VOICEMAIL,
      recording_id: recording.id,
      recording_delivered_manually: 1
    })
    caller_session.emit('publish_message_drop_success')
  end

  def dispositioned(params)
    storage.save({
      questions: params[:question].try(:to_json),
      notes: params[:notes].try(:to_json),
      lead_uuid: params[:lead][:id]
    })

    unless caller_session.is_phones_only?
      unless params[:stop_calling]
        caller_session.redirect_to_hold
      else
        caller_session.stop_calling
      end
    end

    CallFlow::Jobs::Persistence.perform_async('Completed', account_sid, sid)
  end

  def collect_response(params, survey_response)
    for_save = {}
    if storage[:lead_uuid].blank?
      for_save[:lead_uuid] = params[:voter_id]
    end
    storage.save({
      "question_#{survey_response['id']}" => survey_response['possible_response_id']
    }.merge(for_save))
  end

  def drop_message
    Providers::Phone::Jobs::DropMessage.add_to_queue(caller_session_sid, sid)
  end
end

