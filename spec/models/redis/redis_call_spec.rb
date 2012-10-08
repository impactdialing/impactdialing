require "spec_helper"

describe RedisCall do
  
  it "should add the call params to the not answered list" do
    RedisCall.push_to_not_answered_call_list({call_id: 1234, call_status: "busy"})
    RedisCall.not_answered_call_list.length.should eq(1)
    RedisCall.not_answered_call_list.pop.should eq({:call_id=>1234, :call_status=>"busy", :current_time=> Time.now.to_s})
  end
  
  it "should add the call params to the abandoned list" do
    RedisCall.push_to_abandoned_call_list({call_id: 1234, call_status: "in-progress"})
    RedisCall.abandoned_call_list.length.should eq(1)
    RedisCall.abandoned_call_list.pop.should eq({:call_id=>1234, :call_status=>"in-progress", :current_time=> Time.now.to_s})
  end


  it "should add the call params to the processing_by_machine list" do
    RedisCall.push_to_processing_by_machine_call_hash({"id"=> 1234, call_status: "in-progress"})
    RedisCall.processing_by_machine_call_hash['1234'].should eq(Time.now.to_s)
  end
  
  it "should add the call params to the processing_by_machine list" do
    RedisCall.push_to_end_by_machine_call_list({call_id: 1234, call_status: "completed"})
    RedisCall.end_answered_by_machine_call_list.length.should eq(1)
    RedisCall.end_answered_by_machine_call_list.pop.should eq({:call_id=>1234, :call_status=>"completed", :current_time=> Time.now.to_s})
  end
  
  it "should add the call params to the answered call list" do
    RedisCall.push_to_disconnected_call_list({call_id: 1234, call_status: "completed"})
    RedisCall.disconnected_call_list.length.should eq(1)
    RedisCall.disconnected_call_list.pop.should eq({:call_id=>1234, :call_status=>"completed", :current_time=> Time.now.to_s})
  end
  
  it "should add the call params to the wrapup call list" do
    RedisCall.push_to_wrapped_up_call_list({call_id: 1234, call_status: "completed"})
    RedisCall.wrapped_up_call_list.length.should eq(1)
    RedisCall.wrapped_up_call_list.pop.should eq({:call_id=>1234, :call_status=>"completed", :current_time=> Time.now.to_s})
  end
  
  
end
