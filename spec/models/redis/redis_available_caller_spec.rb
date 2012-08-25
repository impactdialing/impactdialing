require "spec_helper"

describe RedisAvailableCaller do
  
  
  
  it "should add caller" do
    RedisAvailableCaller.add_caller(1, 1)
    RedisAvailableCaller.caller?(1, 1).should be_true
  end
  
  it "should remove caller" do
    RedisAvailableCaller.add_caller(1, 1)
    RedisAvailableCaller.remove_caller(1, 1)
    RedisAvailableCaller.caller?(1, 1).should be_false
  end
  
  it "should return the longest waiting caller" do
    RedisAvailableCaller.add_caller(1, 1)
    RedisAvailableCaller.add_caller(2, 1)
    RedisAvailableCaller.longest_waiting_caller(1).should eq(["1"])
  end
  
  it "should return the longest waiting caller when caller is updated" do
    RedisAvailableCaller.add_caller(1, 1)
    RedisAvailableCaller.add_caller(1, 2)
    RedisAvailableCaller.add_caller(1, 1)
    RedisAvailableCaller.longest_waiting_caller(1).should eq(["2"])
  end
  
  

end