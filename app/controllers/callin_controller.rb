class CallinController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :preload_models

  def create
    render :xml => Caller.ask_for_pin
  end

  def identify
    @session = CallerSession.find_by_pin(params[:Digits])
    @caller = @session.try(:caller)
    if @caller
      unless @caller.account.activated?
         render :xml => @caller.account.insufficient_funds
         return
       end
      @session.update_attributes(starttime: Time.now, sid: params[:CallSid]) 
      if !@caller.is_phones_only? && @caller.is_on_call? 
        render xml: @caller.already_on_call
        return
      end

      Moderator.caller_connected_to_campaign(@caller, @caller.campaign, @session)
      render :xml => @caller.is_phones_only? ? @caller.ask_instructions_choice(@session) : @session.start
    else
      render :xml => Caller.ask_for_pin(params[:attempt].to_i)
    end
  end

  def hold
    render :xml => Caller.hold
  end

end
