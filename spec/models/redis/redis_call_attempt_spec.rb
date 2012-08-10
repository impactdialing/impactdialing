require "spec_helper"

describe RedisCallAttempt do
  
  it "should create a new call attempt" do 
    call_attempt = Factory(:call_attempt, caller_id: 1, campaign_id: 1)   
    RedisCallAttempt.load_call_attempt_info(call_attempt.id, call_attempt)
    RedisCallAttempt.read(call_attempt.id).should eq({"call_end"=>"", "call_id"=>"", "call_start"=>"", "caller_id"=>"1", 
    "caller_session_id"=>"", "campaign_id"=>"1", "connecttime"=>"", "created_at"=>"#{Time.now.utc}", "debited"=>"false", 
    "dialer_mode"=>"", "id"=>"#{call_attempt.id}", "payment_id"=>"", "recording_duration"=>"", "recording_url"=>"", 
    "result"=>"", "result_digit"=>"", "scheduled_date"=>"", "sid"=>"", "status"=>"", "tAccountSid"=>"", "tCallSegmentSid"=>"", 
    "tCalled"=>"", "tCaller"=>"", "tDuration"=>"", "tEndTime"=>"", "tFlags"=>"", "tPhoneNumberSid"=>"", "tPrice"=>"", 
    "tStartTime"=>"", "tStatus"=>"", "updated_at"=>"#{Time.now.utc}", "voter_id"=>"", "voter_response_processed"=>"false",
     "wrapup_time"=>""})
  end
  
  describe "connect call" do
    it "should set connect time" do
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
  
  describe "answered_by_machine" do
    
    it "should set status" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.answered_by_machine(1, CallAttempt::Status::VOICEMAIL)      
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::VOICEMAIL)
    end
    
    it "should set connecttime" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.answered_by_machine(1, CallAttempt::Status::VOICEMAIL)      
      RedisCallAttempt.read(1)['connecttime'].should_not be_nil
    end
    
    it "should set call_end" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.answered_by_machine(1, CallAttempt::Status::VOICEMAIL)      
      RedisCallAttempt.read(1)['call_end'].should_not be_nil
    end
    
    it "should set wrapup_time" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.answered_by_machine(1, CallAttempt::Status::VOICEMAIL)      
      RedisCallAttempt.read(1)['wrapup_time'].should_not be_nil
    end
    
    
    
  end
  
  describe "set_status" do
    it "should set status for attempt" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.set_status(1, CallAttempt::Status::SUCCESS)
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::SUCCESS)      
    end
  end

  describe "disconnect_call" do
    
    it "should set status for attempt" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.disconnect_call(1, 12, "url")
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::SUCCESS)      
    end
    
    it "should set recording duration for attempt" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.disconnect_call(1, 12, "url")
      RedisCallAttempt.read(1)['recording_duration'].should eq("12")      
    end
    
    it "should set recording url for attempt" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.disconnect_call(1, 12, "url")
      RedisCallAttempt.read(1)['recording_url'].should eq("url")      
    end
    
    
  end
  
  describe "wrapup" do
    
    it "should set wrapup for attempt" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.wrapup(1)
      RedisCallAttempt.read(1)['wrapup_time'].should_not be_nil
    end
    
    
  end
  
  describe "schedule_for_later" do

    it "should set status for attempt" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.schedule_for_later(1, Time.now)
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::SCHEDULED)
    end

    it "should set scheduled date for attempt" do
      RedisCallAttempt.new(1, 1, 1, "predictive", 1)
      RedisCallAttempt.schedule_for_later(1, Time.now)
      RedisCallAttempt.read(1)['scheduled_date'].should_not be_nil
    end
    
    
  end

end