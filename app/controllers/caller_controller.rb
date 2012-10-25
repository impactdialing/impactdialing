class CallerController < ApplicationController
  include SidekiqEvents
  layout "caller"
  skip_before_filter :verify_authenticity_token, :only =>[:check_reassign, :call_voter, :start_calling, :stop_calling,
     :end_session, :skip_voter, :ready_to_call, :continue_conf, :pause, :run_out_of_numbers, :callin_choice, :read_instruction_options, :conference_started_phones_only_preview, :conference_started_phones_only_power, :conference_started_phones_only_predictive,
     :gather_response, :submit_response, :next_question, :next_call, :time_period_exceeded, :account_out_of_funds]
  
  before_filter :check_login, :except=>[:login, :feedback, :end_session, :start_calling, :phones_only, :new_campaign_response_panel, :check_reassign, :call_voter, 
    :ready_to_call, :continue_conf, :pause, :run_out_of_numbers, :callin_choice, :read_instruction_options, :conference_started_phones_only_preview, :conference_started_phones_only_power, :conference_started_phones_only_predictive,
    :gather_response, :submit_response, :next_question, :next_call, :time_period_exceeded, :account_out_of_funds]
    
  before_filter :find_caller_session , :only => [:pause, :stop_calling, :ready_to_call, :continue_conf, :pause, :run_out_of_numbers, :callin_choice, :read_instruction_options, :conference_started_phones_only_preview, :conference_started_phones_only_power, :conference_started_phones_only_predictive,
    :gather_response, :submit_response, :next_question, :next_call, :time_period_exceeded, :account_out_of_funds]
    
  before_filter :find_session, :only => [:end_session]
  layout 'caller'


  def start_calling
    caller = Caller.find(params[:caller_id])
    identity = CallerIdentity.find_by_session_key(params[:session_key])
    session = caller.create_caller_session(identity.session_key, params[:CallSid], CallerSession::CallerType::TWILIO_CLIENT)
    caller.started_calling(session)    
    render xml: session.start_conf
  end
  
  def ready_to_call
    render xml: @caller_session.ready_to_call
  end
  
  def continue_conf
    render xml: @caller_session.continue_conf
  end
  
  def pause
    render xml: @caller_session.pause
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
  


  def call_voter
    caller = Caller.find(params[:id])
    caller_session = caller.caller_sessions.find(params[:session_id]) 
    caller.calling_voter_preview_power(caller_session, params[:voter_id])
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
    caller_session = @caller.caller_sessions.find(params[:session_id])
    voter = Voter.find(params[:voter_id])
    voter.skip
    enqueue_call_flow(RedirectCallerJob, [caller_session.id])
    render :nothing => true
  end


  def index
    redirect_to callers_campaign_path(@caller.campaign)
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
    if !params[:email].blank?
      @caller = Caller.find_by_email_and_password(params[:email], params[:password])
      if @caller.blank?
        flash_now(:error, "Wrong email or password.")
      elsif !@caller.active?
        flash_now(:error, "Your account has been deleted.")
      else
        session[:caller]= @caller.id
        redirect_to callers_campaign_path(@caller.campaign)
      end
    end
  end

  def kick_caller_off_conference
    caller = Caller.find(params[:id])
    caller_session = caller.caller_sessions.find(params[:caller_session])
    conference_sid = caller_session.get_conference_id
    Twilio.connect(TWILIO_ACCOUNT, TWILIO_AUTH)
    Twilio::Conference.kick_participant(conference_sid, caller_session.sid)
    Twilio::Call.redirect(caller_session.sid, pause_caller_url(caller, session_id:  caller_session.id, host: Settings.twilio_callback_host, port:  Settings.twilio_callback_port, protocol: "http://"))
    caller_session.publish('caller_kicked_off', {})
    render nothing: true
  end


  def check_reassign
    caller = Caller.find(params[:id])
    if caller.campaign.id == params[:campaign_id].to_i
      render :json => {:reassign => "false"}
    else
      render :json => {:reassign => "true", :campaign_id => caller.campaign.id, :script => caller.campaign.try(:script)}
    end
  end

  def new_campaign_response_panel
    caller = Caller.find(params[:id])
    @campaign = caller.campaign
    render :layout => false
  end

  def transfer_panel
    caller = Caller.find(params[:id])
    @campaign = caller.campaign
    render :layout => false
  end


  def feedback
    Postoffice.feedback(params[:issue]).deliver
    render :text=> "var x='ok';"
  end
  
  def find_session
    @caller_session = CallerSession.find_by_sid(params[:CallSid])
  end

  def find_caller_session
    @caller_session = CallerSession.find_by_id(params[:session_id]) || CallerSession.find_by_sid(params[:CallSid])
    optiions = {digit: params[:Digits], question_id: params[:question_id]}
    optiions.merge!(question_number: params[:question_number]) if params[:question_number]
    RedisCallerSession.set_request_params(@caller_session.id, optiions)
    @caller_session
  end

end
