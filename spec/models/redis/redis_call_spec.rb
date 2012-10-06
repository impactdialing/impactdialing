require "spec_helper"

describe RedisCall do
  
  it "should add the call params to the list" do
    RedisCall.store_not_answered_call_list({call_id: 1234, call_status: "busy"})
    RedisCall.not_answered_call_list.length.should eq(1)
    RedisCall.not_answered_call_list.pop.should eq({:call_id=>1234, :call_status=>"busy"})
  end
end
