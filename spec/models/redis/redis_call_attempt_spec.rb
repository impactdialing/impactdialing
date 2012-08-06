require "spec_helper"

describe RedisCallAttempt do
  
  it "should create a new call attempt" do    
    RedisCallAttempt.new(1, 1, 1, "predictive", 1)
    RedisCallAttempt.read(1).should eq({"voter_id"=>"1", "campaign_id"=>"1", "dialer_mode"=>"predictive", "status"=>"Ringing", "caller_id"=>"1", "call_start"=>"#{Time.now}"})
  end
  
  describe "connect call" do
    it "should set connect time" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.connect_call(1, 2, 3)      
      RedisCallAttempt.read(1)['connecttime'].should_not eq(nil)
    end
    
    it "should set status to In progress" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.connect_call(1, 2, 3)      
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::INPROGRESS)
    end
    
    it "should set new caller id" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.connect_call(1, 2, 3)      
      RedisCallAttempt.read(1)['caller_id'].should eq("2")
    end

    it "should set caller_session_id" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.connect_call(1, 2, 3)      
      RedisCallAttempt.read(1)['caller_session_id'].should eq("3")
    end    
    
  end
  
  describe "abandon_call" do
    it "should set connect time" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.abandon_call(1)      
      RedisCallAttempt.read(1)['connecttime'].should_not eq(nil)
    end
    
    it "should set end time" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.abandon_call(1)      
      RedisCallAttempt.read(1)['call_end'].should_not eq(nil)
    end
    
    it "should set wrapup time" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.abandon_call(1)      
      RedisCallAttempt.read(1)['wrapup_time'].should_not eq(nil)
    end
    
    it "should set status to Abandoned" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.abandon_call(1)      
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::ABANDONED)
    end    
  end
  
  describe "end_answered_call" do
    
    it "should set end time" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.end_answered_call(1)      
      RedisCallAttempt.read(1)['call_end'].should_not eq(nil)
    end        
    
  end
  
  describe "call_status_use_recordings" do
    
    it "should set end time" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.end_answered_call(1)      
      RedisCallAttempt.read(1)['call_end'].should_not eq(nil)
    end        
    
  end
end