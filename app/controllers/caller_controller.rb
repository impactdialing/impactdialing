require 'new_relic/agent/method_tracer'
class CallerController < ApplicationController
  include NewRelic::Agent::MethodTracer
  layout "caller"
  skip_before_filter :verify_authenticity_token, :only =>[:check_reassign, :call_voter, :flow, :start_calling, :stop_calling, :end_session, :skip_voter]
  before_filter :check_login, :except=>[:login, :feedback, :end_session, :start_calling, :phones_only, :new_campaign_response_panel, :check_reassign, :call_voter, :flow]
  before_filter :find_caller_session , :only => [:flow, :stop_calling, :end_session]
  
  
  def start_calling
    caller = Caller.find(params[:caller_id])
    identity = CallerIdentity.find_by_session_key(params[:session_key])
    session = caller.create_caller_session(identity.session_key, params[:CallSid], CallerSession::CallerType::TWILIO_CLIENT)
    Moderator.caller_connected_to_campaign(caller, caller.campaign, session)
    render xml: session.run(:start_conf)
  end
  
  def flow
    begin
      response = @caller_session.run(params[:event])
    rescue ActiveRecord::StaleObjectError
      @caller_session.reload
      response = @caller_session.run(params[:event])      
    end    
    render xml:  response
  end
  
  def call_voter
    caller = Caller.find(params[:id])
    caller_session = caller.caller_sessions.find(params[:session_id]) 
    Resque.enqueue(CallerPusherJob, caller_session.id, "publish_calling_voter")   
    caller_session.dial_em(Voter.find(params[:voter_id])) unless params[:voter_id].blank?
    render :nothing => true
  end
  
  def stop_calling
    @caller_session.process('stop_calling') unless @caller_session.nil?
    render :nothing => true
  end
  
  def end_session
    unless @caller_session.nil?
      render xml: @caller_session.run('end_conf') 
    else
      render xml: Twilio::Verb.hangup
    end
  end
  
  def skip_voter
    caller_session = @caller.caller_sessions.find(params[:session_id])
    voter = Voter.find(params[:voter_id])
    voter.skip
    caller_session.redirect_caller
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
    Twilio::Call.redirect(caller_session.sid, flow_caller_url(caller, session_id:  caller_session.id, event: "pause_conf", host: Settings.host, port:  Settings.port))            
    caller_session.publish('caller_kicked_off', {}) 
    render nothing: true
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
  
  def find_caller_session
    @caller_session = CallerSession.find_by_id(params[:session_id]) || CallerSession.find_by_sid(params[:CallSid])
    begin
      @caller_session.try(:update_attributes, {digit: params[:Digits], question_id: params[:question_id]})
    rescue ActiveRecord::StaleObjectError
      @caller_session = CallerSession.find_by_id(params[:session_id]) || CallerSession.find_by_sid(params[:CallSid])
      @caller_session.try(:update_attributes, {digit: params[:Digits], question_id: params[:question_id]})
    end
    @caller_session
  end

end
