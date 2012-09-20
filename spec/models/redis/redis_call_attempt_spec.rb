require "spec_helper"

describe RedisCallAttempt do
  
    
  describe "connect call" do
    
    it "should set connect time" do
      RedisCallAttempt.connect_call(1, 2, 3)      
      RedisCallAttempt.read(1)['connecttime'].should_not eq(nil)
    end
    
    it "should set status to In progress" do
      RedisCallAttempt.connect_call(1, 2, 3)      
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::INPROGRESS)
    end
    
    it "should set new caller id" do
      RedisCallAttempt.connect_call(1, 2, 3)      
      RedisCallAttempt.read(1)['caller_id'].should eq("2")
    end

    it "should set caller_session_id" do
      RedisCallAttempt.connect_call(1, 2, 3)      
      RedisCallAttempt.read(1)['caller_session_id'].should eq("3")
    end    
    
  end
  
  describe "abandon_call" do
    
    it "should set connect time" do
      RedisCallAttempt.abandon_call(1)      
      RedisCallAttempt.read(1)['connecttime'].should_not eq(nil)
    end
    
    it "should set end time" do
      RedisCallAttempt.abandon_call(1)      
      RedisCallAttempt.read(1)['call_end'].should_not eq(nil)
    end
    
    it "should set wrapup time" do
      RedisCallAttempt.abandon_call(1)      
      RedisCallAttempt.read(1)['wrapup_time'].should_not eq(nil)
    end
    
    it "should set status to Abandoned" do
      RedisCallAttempt.abandon_call(1)      
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::ABANDONED)
    end    
  end
  
  describe "end_answered_call" do    
    it "should set end time" do
      RedisCallAttempt.end_answered_call(1)      
      RedisCallAttempt.read(1)['call_end'].should_not eq(nil)
    end        
    
  end
    
  describe "answered_by_machine" do
    
    it "should set status" do
      RedisCallAttempt.answered_by_machine(1, CallAttempt::Status::VOICEMAIL)      
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::VOICEMAIL)
    end
    
    it "should set connecttime" do
      RedisCallAttempt.answered_by_machine(1, CallAttempt::Status::VOICEMAIL)      
      RedisCallAttempt.read(1)['connecttime'].should_not be_nil
    end
    
    it "should set call_end" do
      RedisCallAttempt.answered_by_machine(1, CallAttempt::Status::VOICEMAIL)      
      RedisCallAttempt.read(1)['call_end'].should_not be_nil
    end
    
    it "should set wrapup_time" do
      RedisCallAttempt.answered_by_machine(1, CallAttempt::Status::VOICEMAIL)      
      RedisCallAttempt.read(1)['wrapup_time'].should_not be_nil
    end
    
    
    
  end
  
  describe "end_answered_by_machine" do
    
    it "should set call_end" do
      RedisCallAttempt.end_answered_by_machine(1)      
      RedisCallAttempt.read(1)['call_end'].should_not be_nil            
    end
    
    it "should set wrapup" do
      RedisCallAttempt.end_answered_by_machine(1)      
      RedisCallAttempt.read(1)['wrapup_time'].should_not be_nil            
    end
    
    
  end

  describe "set_status" do
    it "should set status for attempt" do
      RedisCallAttempt.set_status(1, CallAttempt::Status::SUCCESS)
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::SUCCESS)      
    end
  end

  describe "disconnect_call" do
    
    it "should set status for attempt" do
      RedisCallAttempt.disconnect_call(1, 12, "url")
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::SUCCESS)      
    end
    
    it "should set recording duration for attempt" do
      RedisCallAttempt.disconnect_call(1, 12, "url")
      RedisCallAttempt.read(1)['recording_duration'].should eq("12")      
    end
    
    it "should set recording url for attempt" do
      RedisCallAttempt.disconnect_call(1, 12, "url")
      RedisCallAttempt.read(1)['recording_url'].should eq("url")      
    end
    
    
  end
  
  describe "wrapup" do
    
    it "should set wrapup for attempt" do
      RedisCallAttempt.wrapup(1)
      RedisCallAttempt.read(1)['wrapup_time'].should_not be_nil
    end
    
    
  end
  
  describe "schedule_for_later" do

    it "should set status for attempt" do
      RedisCallAttempt.schedule_for_later(1, Time.now)
      RedisCallAttempt.read(1)['status'].should eq(CallAttempt::Status::SCHEDULED)
    end

    it "should set scheduled date for attempt" do
      RedisCallAttempt.schedule_for_later(1, Time.now)
      RedisCallAttempt.read(1)['scheduled_date'].should_not be_nil
    end
    
    
  end

  describe "end_unanswered_call" do
    
    it "should set status" do
      RedisCallAttempt.end_unanswered_call(1, "status")
      RedisCallAttempt.read(1)['status'].should eq('status')            
    end
    
    it "should set call_end" do
      RedisCallAttempt.end_unanswered_call(1, "status")
      RedisCallAttempt.read(1)['call_end'].should_not be_nil
    end

    it "should set wrapup time" do
      RedisCallAttempt.end_unanswered_call(1, "status")
      RedisCallAttempt.read(1)['wrapup_time'].should_not be_nil
    end
    
  end

  describe "update_call_sid" do
    
    it "should set call sid" do
      RedisCallAttempt.update_call_sid(1, "1234")
      RedisCallAttempt.read(1)['sid'].should eq("1234")
    end
    
  end

  describe "failed_call" do
    
    it "should update status as failed" do
      RedisCallAttempt.failed_call(1)
      RedisCallAttempt.read(1)["status"].should eq(CallAttempt::Status::FAILED)      
    end
    
    it "should update wrapuptime" do
      RedisCallAttempt.failed_call(1)
      RedisCallAttempt.read(1)["wrapup_time"].should_not be_nil      
    end
  end
  
  describe "call_not_wrapped_up" do
    
    it"should be false of conencttime is nil" do
      call_attempt = RedisCallAttempt.call_attempt(1)
      call_attempt.store("wrapup_time", "abc")
      RedisCallAttempt.call_not_wrapped_up?(1).should be_false
    end
    
    it"should be true of wrapuptime is nil" do
      call_attempt = RedisCallAttempt.call_attempt(1)
      call_attempt.store("connecttime", "abc")
      RedisCallAttempt.call_not_wrapped_up?(1).should be_true
    end
    
    it"should be false if connecttime and wrapuptime is nil" do
      call_attempt = RedisCallAttempt.call_attempt(1)
      RedisCallAttempt.call_not_wrapped_up?(1).should be_false
    end
    
    it"should be false if connecttime and wrapuptime have values" do
      call_attempt = RedisCallAttempt.call_attempt(1)
      call_attempt.store("connecttime", "abc")
      call_attempt.store("wrapup_time", "abc")
      RedisCallAttempt.call_not_wrapped_up?(1).should be_false
    end
    
    
    
  end
end