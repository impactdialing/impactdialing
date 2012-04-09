class CallinController < ApplicationController
  skip_before_filter :verify_authenticity_token

  def create
    render :xml => Caller.ask_for_pin
  end

  def identify
    @identity = CallerIdentity.find_by_pin(params[:Digits])
    @caller = @identity.nil? ?  Caller.find_by_pin(params[:Digits]) : @identity.try(:caller)
    if @caller
      session_key = @identity.nil? ? generate_session_key : @identity.session_key
      @session = @caller.create_caller_session(session_key, params[:CallSid])
      unless @caller.account.activated?
         render :xml => @caller.account.insufficient_funds
         return
       end
      if !@caller.is_phones_only? && @caller.is_on_call? 
        render xml: @caller.already_on_call
        return
      end

      Moderator.caller_connected_to_campaign(@caller, @caller.campaign, @session)
      @session.publish('start_calling', {caller_session_id: @session.id}) 
      @session.preview_voter
      render :xml => @caller.is_phones_only? ? @caller.ask_instructions_choice(@session) : @session.start
    else
      render :xml => Caller.ask_for_pin(params[:attempt].to_i)
    end
  end

  def hold
    render :xml => Caller.hold
  end

end
