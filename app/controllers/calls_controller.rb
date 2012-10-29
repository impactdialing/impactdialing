class CallsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :parse_params
  before_filter :find_and_update_call, :only => [:destroy, :incoming, :call_ended, :disconnected]
  before_filter :find_and_update_answers_and_notes_and_scheduled_date, :only => [:submit_result, :submit_result_and_stop]
  before_filter :find_call, :only => [:hangup, :call_ended]

    
  def incoming
    if Campaign.predictive_campaign?(params['campaign_type']) && @call.answered_by_human? 
      call_attempt = @call.call_attempt
      call_attempt.connect_caller_to_lead(DataCentre.code(params[:calledc]))
    end
    render xml: @call.incoming_call
  end  
  
  def call_ended    
    render xml:  @call.call_ended(params['campaign_type'])
  end
  
  def submit_result
    @call.wrapup_and_continue
    render nothing: true
  end
  
  def submit_result_and_stop
    @call.wrapup_and_stop
    render nothing: true
  end
  
  def hangup
    @call.hungup
    render nothing: true
  end
  
  def disconnected
    render xml: @call.disconnected    
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
      RedisCall.set_request_params(@call.id, @parsed_params)
      unless params[:scheduled_date].blank?
        scheduled_date = params[:scheduled_date] + " " + params[:callback_time_hours] +":" + params[:callback_time_minutes]
        @call.call_attempt.schedule_for_later(scheduled_date)
      end
    end
  end
  

  def find_and_update_call
    find_call
    unless @call.nil?    
      RedisCall.set_request_params(@call.id, @parsed_params)
    end
  end
  
  
end