require "spec_helper"

describe RedisOnHoldCaller do
  
  it "should add caller" do
    RedisOnHoldCaller.add(1, 1)
    RedisOnHoldCaller.longest_waiting_caller(1).should eq("1")
    RedisOnHoldCaller.longest_waiting_caller(1).should eq(nil)
  end
  
  it "should remove caller" do
    RedisOnHoldCaller.add(1, 1)
    RedisOnHoldCaller.remove_caller_session(1, 1)
    RedisOnHoldCaller.longest_waiting_caller(1).should eq(nil)
  end
  
  it "should add to bottom of list" do
    RedisOnHoldCaller.add(1, 1)
    RedisOnHoldCaller.add_to_bottom(1, 2)
    RedisOnHoldCaller.longest_waiting_caller(1).should eq("2")
  end
end
