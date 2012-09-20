require "spec_helper"

describe RedisCaller do
  
  
  
  it "should add caller" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.add_caller(1, 2)
    RedisCaller.caller?(1, 1).should be_true
  end
  
  it "should disconnect caller" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.disconnect_caller(1, 1)
    RedisCaller.caller?(1, 1).should be_false
  end
  
  it "should give count of callers" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.add_caller(2, 1)
    RedisCaller.add_caller(1, 2)
    RedisCaller.count(1).should eq(2)
    
  end
  
  it "should return the longest waiting caller" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.add_caller(2, 1)
    RedisCaller.longest_waiting_caller(1).should eq("1")
  end
  
  it "should return the longest waiting caller when caller is updated" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.add_caller(1, 2)
    RedisCaller.add_caller(1, 1)
    RedisCaller.longest_waiting_caller(1).should eq("2")
  end
  
end