class CallsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :parse_params
  before_filter :find_and_update_call, :only => [:destroy, :incoming, :call_ended, :disconnected]
  before_filter :find_and_update_answers_and_notes_and_scheduled_date, :only => [:submit_result, :submit_result_and_stop]
  before_filter :find_call, :only => [:hangup, :call_ended, :drop_message, :play_message]


  # TwiML
  def incoming
    if Campaign.predictive_campaign?(params['campaign_type']) && @call.answered_by_human?
      call_attempt = @call.call_attempt
      call_attempt.connect_caller_to_lead(DataCentre.code(params[:callee_dc]))
    end
    render xml: @call.incoming_call
  end

  # TwiML
  def call_ended
    render xml:  @call.call_ended(params['campaign_type'], params)
  end

  # TwiML
  def disconnected
    render xml: @call.disconnected
  end

  # TwiML
  def play_message
    xml = @call.play_message_twiml

    @call.enqueue_call_flow(Providers::Phone::Jobs::DropMessageRecorder, [@call.id, 1])
    @call.enqueue_call_flow(CallerPusherJob, [@call.caller_session.id, 'publish_message_drop_success'])

    render xml: xml
  end

  # Browser
  def submit_result
    @call.wrapup_and_continue
    render nothing: true
  end

  # Browser
  def submit_result_and_stop
    @call.wrapup_and_stop
    render nothing: true
  end

  # Browser
  def hangup
    @call.hungup
    render nothing: true
  end

  # Browser
  def drop_message
    @call.enqueue_call_flow(Providers::Phone::Jobs::DropMessage, [@call.id])

    render nothing: true
  end

  private
  ##
  # Used to initialize @parsed_params to empty Hash for submit_result &
  # submit_result_and_stop.
  # Used to init @parsed_params to populated Hash for Twilio callbacks
  # (:destroy, :incoming, :call_ended, :disconnected)
  #
  def parse_params
    pms = underscore_params
    @parsed_params = Call.column_names.inject({}) do |result, key|
      value = pms[key]
      result[key] = value unless value.blank?
      result
    end
  end

  def underscore_params
    params.inject({}) do |result, k_v|
      k, v = k_v
      result[k.underscore] = v
      result
    end
  end

  def find_call
    @call = Call.where('id = ? OR call_sid = ?', params['id'], params['CallSid']).includes(call_attempt: [:caller, :household, :campaign, :caller_session]).first
  end

  def find_and_update_answers_and_notes_and_scheduled_date
    find_call
    
    madd = "MissingAnswerDataDebug "

    unless @call.nil?
      madd << "Call[#{@call.id}]"

      @parsed_params["questions"] = params[:question].try(:to_json)
      @parsed_params["notes"] = params[:notes].try(:to_json)

      p "#{madd} parsed_params['questions']#{@parsed_params['questions']}"
      p "#{madd} parsed_params['notes']#{@parsed_params['notes']}"

      RedisCall.set_request_params(@call.id, @parsed_params)
    else
      madd << "Call[NotFound:#{params[:id]}]"
    end

    p "#{madd} params[:question]#{params[:question]}"
    p "#{madd} params[:notes]#{params[:notes]}"
  end

  def find_and_update_call
    find_call
    unless @call.nil?
      RedisCall.set_request_params(@call.id, @parsed_params)
    end
  end


end
