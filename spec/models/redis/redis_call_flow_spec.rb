require "spec_helper"

describe RedisCallFlow, :type => :model do
  
  it "should add the call params to the not answered list" do
    RedisCallFlow.push_to_not_answered_call_list(1234, "busy")
    expect(RedisCallFlow.not_answered_call_list.length).to eq(1)
    expect(RedisCallFlow.not_answered_call_list.pop).to eq("{\"id\":1234,\"call_status\":\"busy\",\"current_time\":\"#{Time.now.to_s}\"}")
  end
  
  it "should add the call params to the abandoned list" do
    RedisCallFlow.push_to_abandoned_call_list(1234)
    expect(RedisCallFlow.abandoned_call_list.length).to eq(1)
    expect(RedisCallFlow.abandoned_call_list.pop).to eq("{\"id\":1234,\"current_time\":\"#{Time.now.to_s}\"}")
  end


  it "should add the call params to the processing_by_machine list" do
    RedisCallFlow.push_to_processing_by_machine_call_hash(1234)
    expect(RedisCallFlow.processing_by_machine_call_hash['1234']).to eq(Time.now.to_s)
  end
  
  it "should add the call params to the end_by_machine list" do
    RedisCallFlow.push_to_end_by_machine_call_list(1234)
    expect(RedisCallFlow.end_answered_by_machine_call_list.length).to eq(1)
    expect(RedisCallFlow.end_answered_by_machine_call_list.pop).to eq("{\"id\":1234,\"current_time\":\"#{Time.now.to_s}\"}")
  end
  
  it "should add the call params to the answered call list" do
    RedisCallFlow.push_to_disconnected_call_list(1234, 15, "url", 1)
    expect(RedisCallFlow.disconnected_call_list.length).to eq(1)
    expect(RedisCallFlow.disconnected_call_list.pop).to eq("{\"id\":1234,\"recording_duration\":15,\"recording_url\":\"url\",\"caller_id\":1,\"current_time\":\"#{Time.now.to_s}\"}")
  end
  
  it "should add the call params to the wrapup call list" do
    RedisCallFlow.push_to_wrapped_up_call_list(1234, CallerSession::CallerType::TWILIO_CLIENT)
    expect(RedisCallFlow.wrapped_up_call_list.length).to eq(1)
    expect(RedisCallFlow.wrapped_up_call_list.pop).to eq("{\"id\":1234,\"caller_type\":\"Twilio client\",\"current_time\":\"#{Time.now.to_s}\"}")
  end
  
  
end
