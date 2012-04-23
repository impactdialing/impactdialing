class CallsController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :parse_params
  before_filter :find_and_update_call, :only => [:flow, :destroy]
  before_filter :find_call, :only=> [:submit_result, :submit_result_and_stop]
  

  def create
    @call = Call.create!(@parsed_params)
    render xml:  @call.run(:incoming_call)
  end

  def flow
    render xml:  @call.run(params[:event])
  end
  
  def submit_result
    @call.process(params[:event])
  end
  
  def submit_result_and_stop
    @call.process(params[:event])
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
    @call = (Call.find_by_id(params["call_id"]) || Call.find_by_call_sid(params['CallSid']))
  end

  def find_and_update_call
    find_call
    @call.update_attributes(@parsed_params)
  end
  
  
end