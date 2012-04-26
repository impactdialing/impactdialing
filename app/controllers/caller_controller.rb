require 'new_relic/agent/method_tracer'
class CallerController < ApplicationController
  include NewRelic::Agent::MethodTracer
  layout "caller"
  before_filter :check_login, :except=>[:login, :feedback, :assign_campaign, :end_session, :pause, :start_calling, :gather_response, :choose_voter, :phones_only_progressive, :phones_only, :choose_instructions_option, :new_campaign_response_panel, :check_reassign, :call_voter, :flow]
  before_filter :redirect_to_ssl
  
  
  def start_calling
    caller = Caller.find(params[:caller_id])
    identity = CallerIdentity.find_by_session_key(params[:session_key])
    session = caller.create_caller_session(identity.session_key, params[:CallSid])
    render xml: session.run(:start_conf)
  end
  
  def flow
    call_session = CallerSession.find(params[:session_id])
    begin
      response = call_session.run(params[:event])
    rescue ActiveRecord::StaleObjectError
      call_session.reload
      response = call_session.run(params[:event])      
    end    
    render xml:  response
  end
  
  def call_voter
    caller = Caller.find(params[:id])
    caller_session = caller.caller_sessions.find(params[:session_id])    
    caller_session.dial(Voter.find(params[:voter_id])) unless params[:voter_id].blank?
    render :nothing => true
  end
  
  def stop_calling
    caller_session = WebuiCallerSession.find(params[:session_id])
    caller_session.process('stop_calling')
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
    @breadcrumb="Login"
    @title="Login to Impact Dialing"

    if !params[:email].blank?
      @caller = Caller.find_by_email_and_password(params[:email], params[:password])
      if @caller.blank?
        flash_now(:error, "Wrong email or password.")
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
    Twilio::Call.redirect(caller_session.sid, pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => caller_session.id))            
    caller_session.publish('caller_kicked_off', {}) 
    render nothing: true
  end


  def gather_response
    caller = Caller.find(params[:id])
    caller_session = caller.caller_sessions.find(params[:session_id])
    question = Question.find_by_id(params[:question_id])
    voter = caller_session.voter_in_progress
    voter.answer(question, params[:Digits], caller_session) if voter && question

    xml = Twilio::Verb.hangup if caller_session.disconnected?
    xml ||= (voter.question_not_answered.try(:read, caller_session) if voter)
    xml ||= caller_session.ask_caller_to_choose_voter if (caller.is_phones_only? && caller.campaign.is_preview_or_progressive)
    xml ||= caller_session.start
    render :xml => xml
  end


  def end_session
    caller_session = CallerSession.find_by_sid(params[:CallSid])
    caller_session.debit if caller_session!=nil
    begin
      render xml:  caller_session.try(:end) || Twilio::Verb.hangup
    rescue ActiveRecord::StaleObjectError
      caller_session.reload
      render xml: caller_session.end      
    end
  end

  def skip_voter
    caller_session = @caller.caller_sessions.find(params[:session_id])
    voter = Voter.find(params[:voter_id])
    voter.skip
    next_voter = caller_session.campaign.next_voter_in_dial_queue(params[:voter_id])
    caller_session.publish('caller_connected', next_voter ? next_voter.info : {}) 
    render :nothing => true
  end
  
  def check_reassign
    caller = Caller.find(params[:id])
    if caller.campaign.id == params[:campaign_id].to_i
      render :json => {:reassign => "false"}
    else
      render :json => {:reassign => "true", :campaign_id => caller.campaign.id, :script => caller.campaign.script.try(:script)}
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

end
