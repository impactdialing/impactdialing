class CallerController < ApplicationController
  include SidekiqEvents
  layout "caller"
  skip_before_filter :verify_authenticity_token, :only =>[
    :call_voter, :start_calling, :stop_calling, :token,
    :end_session, :skip_voter, :ready_to_call,
    :continue_conf, :pause, :run_out_of_numbers,
    :callin_choice, :read_instruction_options,
    :conference_started_phones_only_preview,
    :conference_started_phones_only_power,
    :conference_started_phones_only_predictive,
    :gather_response, :submit_response, :next_question,
    :next_call, :time_period_exceeded,
    :account_out_of_funds, :datacentre, :kick,
    :play_message_error
  ]

  before_filter :check_login, :except=>[
    :login, :feedback, :end_session, :start_calling,
    :phones_only, :call_voter, :skip_voter, :stop_calling,
    :ready_to_call, :continue_conf, :pause, :run_out_of_numbers,
    :callin_choice, :read_instruction_options,
    :conference_started_phones_only_preview,
    :conference_started_phones_only_power,
    :conference_started_phones_only_predictive,
    :gather_response, :submit_response, :next_question,
    :next_call, :time_period_exceeded,
    :account_out_of_funds, :datacentre, :kick,
    :play_message_error
  ]

  before_filter :find_caller_session , :only => [
    :pause, :stop_calling, :ready_to_call,
    :continue_conf, :pause, :run_out_of_numbers,
    :callin_choice, :read_instruction_options,
    :conference_started_phones_only_preview,
    :conference_started_phones_only_power,
    :conference_started_phones_only_predictive,
    :gather_response, :submit_response, :next_question,
    :next_call, :time_period_exceeded,
    :account_out_of_funds
  ]

  before_filter :find_session, :only => [:end_session]

  def start_calling
    caller = Caller.find(params[:caller_id])
    identity = CallerIdentity.find_by_session_key(params[:session_key])
    session = caller.create_caller_session(identity.session_key, params[:CallSid], CallerSession::CallerType::TWILIO_CLIENT)
    load_caller_session = CallerSession.find_by_id_cached(session.id)
    caller.started_calling(load_caller_session)
    RedisDataCentre.set_datacentres_used(load_caller_session.campaign_id, DataCentre.code(params[:caller_dc]))
    render xml: load_caller_session.start_conf
  end

  def ready_to_call
    RedisDataCentre.set_datacentres_used(@caller_session.campaign_id, DataCentre.code(params[:caller_dc]))
    render xml: @caller_session.ready_to_call(DataCentre.code(params[:caller_dc]))
  end

  def continue_conf
    render xml: @caller_session.continue_conf
  end

  # This is the Dial:action for most caller TwiML
  # so expect Caller to hit here for >1 state changes
  def pause
    # ^^ Work around; this url can be removed from some Dial:actions
    # todo: remove pause_url from unnecessary TwiML responses
    logger.debug "DoublePause: Caller#pause - #{params}"
    if RedisCallerSession.pause?(@caller_session.session_key, params[:transfer_session_key])

      @caller_session.publish('caller_wrapup_voice_hit', {})

      logger.debug "DoublePause: Caller#pause - pausing for results"

      xml = Twilio::TwiML::Response.new do |r|
        r.Say("Please enter your call results.")
        r.Pause("length" => 600)
      end.text
    else
      logger.debug "DoublePause: Caller#pause - waiting 0.5 seconds"
      # Caller on warm transfer (RedisCallerSession.active_transfer?).
      xml = Twilio::TwiML::Response.new do |r|
        # Wait quietly for .5 seconds
        # while caller joins transfer conference.
        r.Play("digits" => "w")
      end.text
    end
    RedisCallerSession.after_pause(@caller_session.session_key, params[:transfer_session_key])
    render xml: xml
  end

  def run_out_of_numbers
    render xml: @caller_session.campaign_out_of_phone_numbers
  end

  def callin_choice
    render xml: @caller_session.callin_choice
  end

  def read_instruction_options
    render xml: @caller_session.read_choice
  end

  def conference_started_phones_only_preview
    render xml: @caller_session.conference_started_phones_only_preview
  end

  def conference_started_phones_only_power
    render xml: @caller_session.conference_started_phones_only_power
  end

  def conference_started_phones_only_predictive
    render xml: @caller_session.conference_started_phones_only_predictive
  end

  def gather_response
    render xml: @caller_session.gather_response
  end

  def submit_response
    render xml: @caller_session.submit_response
  end

  def next_question
    render xml: @caller_session.next_question
  end

  def next_call
    render xml: @caller_session.next_call
  end

  def time_period_exceeded
    render xml: @caller_session.time_period_exceeded
  end

  def account_out_of_funds
    render xml: @caller_session.account_has_no_funds
  end

  def play_message_error
    msg = I18n.t('dialer.message_drop.failed')
    xml = Twilio::TwiML::Response.new do |r|
      r.Say(msg)
      r.Pause("length" => 600)
    end.text

    render xml: xml
  end

  def call_voter
    caller = Caller.find(params[:id])
    campaign = caller.campaign
    caller_session = caller.caller_sessions.find(params[:session_id])

    Rails.logger.error "RecycleRate Caller#call_voter #{campaign.try(:type) || 'Campaign'}[#{campaign.try(:id)}] CallerSession[#{caller_session.id}] Voter[#{params[:voter_id]}]"

    if params[:voter_id].present?
      voter = Voter.find params[:voter_id]
    end
    if params[:voter_id].blank? || (params[:voter_id].present? && campaign.within_recycle_rate?(voter))
      Rails.logger.error "RecycleRate Caller#call_voter #{campaign.try(:type) || 'Campaign'}[#{campaign.try(:id)}] CallerSession[#{caller_session.id}] Voter[#{params[:voter_id]}] - queueing conference_started"
      enqueue_call_flow(CallerPusherJob, [caller_session.id,  "publish_caller_conference_started"])
    else
      # publish_calling_voter &
      # queue PreviewPowerDialJob
      Rails.logger.error "RecycleRate Caller#call_voter #{campaign.try(:type) || 'Campaign'}[#{campaign.try(:id)}] CallerSession[#{caller_session.id}] Voter[#{params[:voter_id]}] - queueing calling_voter & PreviewPowerDialJob"
      caller.calling_voter_preview_power(caller_session, params[:voter_id])
    end
    render :nothing => true
  end

  def stop_calling
    @caller_session.stop_calling unless @caller_session.nil?
    render :nothing => true
  end

  def end_session
    unless @caller_session.nil?
      render xml: @caller_session.conference_ended
    else
      render xml: Twilio::Verb.hangup
    end
  end

  def skip_voter
    caller = Caller.includes(:campaign).find(params[:id])
    caller_session = caller.caller_sessions.find(params[:session_id])
    voter = Voter.find(params[:voter_id])
    voter.skip
    info = caller.campaign.caller_conference_started_event(voter.id)

    render json: info[:data].to_json
  end


  def index
    redirect_to callveyor_path if @caller.campaign
  end

  # todo: remove when old caller app can be retired.
  def v1
    redirect_to callers_campaign_calls_path + "/" + @caller.campaign.id.to_s if @caller.campaign
  end

  def check_login
    if session[:caller].blank?
      redirect_to caller_login_path
      return
    end
    begin
      @caller = Caller.find(session[:caller])
    rescue
      logout
    end
  end

  def logout
    session[:caller]=nil
    redirect_to caller_login_path
  end

  def login
    if !params[:username].blank?
      @caller = Caller.find_by_username_and_password(params[:username], params[:password])
      if @caller.blank?
        flash_now(:error, "Wrong username or password.")
      elsif !@caller.active?
        flash_now(:error, "Your account has been deleted.")
      else
        session[:caller]= @caller.id
        redirect_to callers_campaign_call_path(@caller.campaign)
      end
    end
  end

  def kick
    logger.debug "DoublePause: Caller#kick #{params[:participant_type]}"
    check_login
    @caller_session = @caller.caller_sessions.find(params[:caller_session_id])
    transfer_attempt = @caller_session.transfer_attempts.last
    participant_type = params[:participant_type]
    case participant_type
    when 'transfer'
      Providers::Phone::Conference.kick(transfer_attempt, {retry_up_to: ENV["TWILIO_RETRIES"]})
      RedisCallerSession.remove_party(transfer_attempt.session_key)
    when 'caller'
      Providers::Phone::Conference.kick(@caller_session, {retry_up_to: ENV["TWILIO_RETRIES"]})

      if transfer_attempt.warm_transfer?
        if RedisCallerSession.party_count(transfer_attempt.session_key) == 3
          RedisCallerSession.remove_party(transfer_attempt.session_key) # Lead
          RedisCallerSession.remove_party(transfer_attempt.session_key) # Transfer
        end
        if RedisCallerSession.party_count(transfer_attempt.session_key) == 2
          RedisCallerSession.remove_party(transfer_attempt.session_key) # Lead
        end
      end
      # this redirect probably isn't necessary since the Dial:action url is set to the pause_url in TransfersController#caller
      # this redirect is only necessary in order to update the Call
      # and trigger the Dial:action from the caller conference twiml
      # in transfers#caller
      # todo: file ticket w/ twilio asking why Dial:action isn't followed after kicking participant
      Providers::Phone::Call.redirect_for(@caller_session, :pause)
      @caller_session.publish('caller_kicked_off', {})
    end
    render nothing: true
  end

  def feedback
    Postoffice.feedback(params[:issue]).deliver
    render :text=> "var x='ok';"
  end

  def find_session
    @caller_session = CallerSession.find_by_sid_cached(params[:CallSid])
  end

  def find_caller_session
    @caller_session = CallerSession.find_by_id_cached(params[:session_id]) || CallerSession.find_by_sid_cached(params[:CallSid])
    optiions = {digit: params[:Digits], question_id: params[:question_id]}
    optiions.merge!(question_number: params[:question_number]) if params[:question_number]
    RedisCallerSession.set_request_params(@caller_session.id, optiions)
    @caller_session
  end

end
