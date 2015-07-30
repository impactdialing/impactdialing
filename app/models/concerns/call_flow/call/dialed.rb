class CallFlow::Call::Dialed < CallFlow::Call::Lead
  attr_reader :twiml_flag, :recording_url, :record_calls

private
  def self.storage_key(rest_response)
    CallFlow::Call::Storage.key(rest_response['account_sid'], rest_response['sid'], 'dialed')
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
    [:campaign_id, :campaign_type].each do |key|
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
  def handle_successful_dial(campaign, caller_session, params)
    if campaign.predictive? and answered_by_human?(params)
      Twillio.predictive_dial_answered(caller_session, params)
    end

    if answered_by_human?(params) and call_in_progress?(params)
      attempt_connection(campaign, caller_session, params)
    else
      call_answered_by_machine(campaign, caller_session, params)
    end
  end
  def attempt_connection(campaign, caller_session, params)
    if caller_session.on_call? and (not caller_session.available_for_call?)
      RedisStatus.set_state_changed_time(campaign.id, "On call", caller_session.id)
      VoterConnectedPusherJob.add_to_queue(caller_session.id, params[:CallSid])
      @twiml_flag   = :connect
      @record_calls = campaign.account.record_calls.to_s
    else
      @twiml_flag = :hangup
    end
  end
  def call_answered_by_machine(campaign, caller_session, params)
    RedirectCallerJob.add_to_queue(caller_session.id)
    answering_machine_agent = AnsweringMachineAgent.new(campaign, storage[:phone])

    if answering_machine_agent.leave_message?
      @twiml_flag    = :leave_message
      @recording_url = campaign.recording.file.url
      answering_machine_agent.record_message_drop
    else
      @twiml_flag = :hangup
    end
  end
  def answered_by_machine?(params)
    params[:AnsweredBy] == 'machine'
  end
  def answered_by_human?(params)
    not answered_by_machine?(params)
  end
  def call_in_progress?(params)
    params[:CallStatus] == 'in-progress'
  end

public
  def self.create(campaign, rest_response, optional_properties={})
    opts = lua_options(campaign, rest_response, optional_properties)
    Wolverine.call_flow.dialed(opts)
    if campaign.class.to_s !~ /(Preview|Power|Predictive)/ or campaign.new_record?
      raise ArgumentError, "CallFlow::Call::Dialed received new or unknown campaign: #{campaign.class}"
    end

    self.new(rest_response['account_sid'], rest_response['sid'])
  end

  def self.namespace
    'dialed'
  end

  def namespace
    self.class.namespace
  end

  def caller_session_from_sid
    @caller_session ||= CallerSession.where(sid: self.caller_session_sid).first
  end

  def caller_session_from_id(campaign, params)
    @caller_session ||= if campaign.predictive? and answered_by_human?(params)
                          caller_session_id = RedisOnHoldCaller.longest_waiting_caller(campaign.id)
                          CallerSession.find(caller_session_id)
                        end
  end

  def answered(campaign, params)
    update_history(:answered)
    campaign.number_not_ringing
    storage.save(params_for_update(params))

    caller_session = caller_session_from_id(campaign, params) || caller_session_from_sid

    unless params['ErrorCode'] and params['ErrorUrl']
      handle_successful_dial(campaign, caller_session, params)
    else
      handle_failed_dial(campaign, params)
    end
  end

  def disconnected(params)
    storage.save(params_for_update(params))

    caller_session = caller_session_from_sid
    unless caller_session.nil?
      CallerPusherJob.add_to_queue(caller_session.id, 'publish_voter_disconnected')
    end
  end

  def completed(campaign, params)
    storage.save(params_for_update(params))

    caller_session = caller_session_from_sid
    CallerPusherJob.add_to_queue(caller_session.id, 'call_ended')

    if state_missed?(:answered)
      campaign.number_not_ringing

      unless campaign.predictive?
        RedirectCallerJob.add_to_queue(caller_session.id)
      end
    end
  end
end

