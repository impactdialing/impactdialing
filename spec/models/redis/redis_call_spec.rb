require "spec_helper"

describe RedisCall do
  
  it "should add the call params to the not answered list" do
    RedisCall.push_to_not_answered_call_list(1234, "busy")
    RedisCall.not_answered_call_list.length.should eq(1)
    RedisCall.not_answered_call_list.pop.should eq("{\"id\":1234,\"call_status\":\"busy\",\"current_time\":\"#{Time.now.to_s}\"}")
  end
  
  it "should add the call params to the abandoned list" do
    RedisCall.push_to_abandoned_call_list(1234)
    RedisCall.abandoned_call_list.length.should eq(1)
    RedisCall.abandoned_call_list.pop.should eq("{\"id\":1234,\"current_time\":\"#{Time.now.to_s}\"}")
  end


  it "should add the call params to the processing_by_machine list" do
    RedisCall.push_to_processing_by_machine_call_hash(1234)
    RedisCall.processing_by_machine_call_hash['1234'].should eq(Time.now.to_s)
  end
  
  it "should add the call params to the end_by_machine list" do
    RedisCall.push_to_end_by_machine_call_list(1234)
    RedisCall.end_answered_by_machine_call_list.length.should eq(1)
    RedisCall.end_answered_by_machine_call_list.pop.should eq("{\"id\":1234,\"current_time\":\"#{Time.now.to_s}\"}")
  end
  
  it "should add the call params to the answered call list" do
    RedisCall.push_to_disconnected_call_list(1234, 15, "url", 1)
    RedisCall.disconnected_call_list.length.should eq(1)
    RedisCall.disconnected_call_list.pop.should eq("{\"id\":1234,\"recording_duration\":15,\"recording_url\":\"url\",\"caller_id\":1,\"current_time\":\"#{Time.now.to_s}\"}")
  end
  
  it "should add the call params to the wrapup call list" do
    RedisCall.push_to_wrapped_up_call_list(1234, CallerSession::CallerType::TWILIO_CLIENT)
    RedisCall.wrapped_up_call_list.length.should eq(1)
    RedisCall.wrapped_up_call_list.pop.should eq("{\"id\":1234,\"caller_type\":\"Twilio client\",\"current_time\":\"#{Time.now.to_s}\"}")
  end
  
  
end
