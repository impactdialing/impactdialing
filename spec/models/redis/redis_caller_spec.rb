require "spec_helper"

describe RedisCaller do
  
  
  
  it "should add caller" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.add_caller(1, 2)
    RedisCaller.caller?(1, 1).should be_true
  end
  
  it "should disconnect caller on hold" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.disconnect_caller(1, 1)
    RedisCaller.caller?(1, 1).should be_false
    RedisCaller.disconnected?(1,1).should be_true
    RedisCaller.on_hold(1).member?(1).should be_false
  end
  
  it "should disconnect caller on call" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.move_on_hold_to_on_call(1,1)
    RedisCaller.disconnect_caller(1, 1)
    RedisCaller.caller?(1, 1).should be_false
    RedisCaller.disconnected?(1,1).should be_true
    RedisCaller.on_call(1).member?(1).should be_false    
  end
  
  it "should disconnect caller in wrapup" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.move_on_hold_to_on_call(1,1)
    RedisCaller.move_on_call_to_on_wrapup(1,1)
    RedisCaller.disconnect_caller(1, 1)
    RedisCaller.caller?(1, 1).should be_false
    RedisCaller.disconnected?(1,1).should be_true
    RedisCaller.on_wrapup(1).member?(1).should be_false    
  end
  
  it "should move caller from on call to on hold" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.move_on_hold_to_on_call(1,1)
    RedisCaller.move_to_on_hold(1,1)
    RedisCaller.on_call(1).member?(1).should be_false    
    RedisCaller.on_hold(1).member?(1).should be_true        
  end
  
  it "should move caller from in wrapup to on hold" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.move_on_hold_to_on_call(1,1)
    RedisCaller.move_on_call_to_on_wrapup(1,1)
    RedisCaller.move_to_on_hold(1,1)
    RedisCaller.on_wrapup(1).member?(1).should be_false    
    RedisCaller.on_hold(1).member?(1).should be_true        
  end
  
  
  
  
  it "should give count of callers" do
    RedisCaller.add_caller(1, 1)
    RedisCaller.add_caller(2, 1)
    RedisCaller.add_caller(1, 2)
    RedisCaller.count(1).should eq(2)    
  end
  
end