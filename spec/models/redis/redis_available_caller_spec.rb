require "spec_helper"

describe RedisAvailableCaller do
  
  before(:each) do
    @redis = RedisConnection.call_flow_connection
  end
  
  
  it "should add caller" do
    RedisAvailableCaller.add_caller(1, 1, @redis)
    RedisAvailableCaller.caller?(1, 1, @redis).should be_true
  end
  
  it "should remove caller" do
    RedisAvailableCaller.add_caller(1, 1, @redis)
    RedisAvailableCaller.remove_caller(1, 1, @redis)
    RedisAvailableCaller.caller?(1, 1, @redis).should be_false
  end
  
  it "should return the longest waiting caller" do
    RedisAvailableCaller.add_caller(1, 1, @redis)
    RedisAvailableCaller.add_caller(2, 1, @redis)
    RedisAvailableCaller.longest_waiting_caller(1, @redis).should eq(["1"])
  end
  
  it "should return the longest waiting caller when caller is updated" do
    RedisAvailableCaller.add_caller(1, 1, @redis)
    RedisAvailableCaller.add_caller(1, 2, @redis)
    RedisAvailableCaller.add_caller(1, 1, @redis)
    RedisAvailableCaller.longest_waiting_caller(1, @redis).should eq(["2"])
  end
  
  

end