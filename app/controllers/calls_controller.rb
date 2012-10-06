class CallsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :parse_params
  before_filter :find_and_update_call, :only => [:flow, :destroy]
  before_filter :find_and_update_answers_and_notes_and_scheduled_date, :only => [:submit_result, :submit_result_and_stop]
  before_filter :find_call, :only => [:hangup, :call_ended]

  
  def flow    
    unless @call.nil?
      render xml:  @call.run(params[:event]) 
    else      
      render xml: Twilio::Verb.hangup
    end
  end
  
  def call_ended    
    if ["no-answer", "busy", "failed"].include?(@parsed_params['call_status']) || @parsed_params['answered_by'] == "machine"
      RedisCall.store_not_answered_call_list(@parsed_params)
    end
        
    if @parsed_params['campaign_type'] != Campaign::Type::PREDICTIVE && @parsed_params['call_status'] != 'completed'
      @call.call_attempt.redirect_caller
    end      
    
    render xml:  Twilio::TwiML::Response.new { |r| r.Hangup }.text
  end
  
  def submit_result
    @call.process("submit_result")
    render nothing: true
  end
  
  def submit_result_and_stop
    @call.process("submit_result_and_stop")
    render nothing: true
  end
  
  def hangup
    @call.process('hangup')
    render nothing: true
  end
  
  
  
  private
    
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
    @call = (Call.find_by_id(params["id"]) || Call.find_by_call_sid(params['CallSid'])) 
  end
  
  def find_and_update_answers_and_notes_and_scheduled_date
    find_call    
    unless @call.nil?      
      @parsed_params["questions"]  = params[:question].try(:to_json) 
      @parsed_params["notes"] = params[:notes].try(:to_json)
      @parsed_params["all_states"] =  @call.all_states + "|" + @call.state unless @call.all_states.nil?
      @call.update_attributes(@parsed_params)
      unless params[:scheduled_date].blank?
        scheduled_date = params[:scheduled_date] + " " + params[:callback_time_hours] +":" + params[:callback_time_minutes]
        @call.call_attempt.schedule_for_later(scheduled_date)
      end
    end
  end
  

  def find_and_update_call
    find_call
    unless @call.nil?    
      @parsed_params["all_states"] =  @call.all_states + "|" + @call.state unless @call.all_states.nil?
      @call.update_attributes(@parsed_params)
    end
  end
  
  
end