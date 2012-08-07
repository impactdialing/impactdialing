require "spec_helper"

describe RedisVoter do
  
  it "should redis voter" do
    voter_list = Factory(:voter_list)
    voter = Factory(:voter, voter_list: voter_list, FirstName: "abc")
    RedisVoter.load_voter_info(voter.id, voter)
    RedisVoter.read(voter.id).should eq({"CustomID"=>"", "Email"=>"", "FirstName"=>"abc", "LastName"=>"",
    "MiddleName"=>"", "Phone"=>"10000000001", "Suffix"=>"", "account_id"=>"", "active"=>"true", "address"=>"", 
    "attempt_id"=>"", "call_back"=>"false", "caller_id"=>"", "caller_session_id"=>"", "campaign_id"=>"", "city"=>"", 
    "country"=>"", "created_at"=>"#{Time.now.utc}", "enabled"=>"true", "family_id_answered"=>"", "id"=>"#{voter.id}", 
    "last_call_attempt_id"=>"", "last_call_attempt_time"=>"", "lock_version"=>"0", "num_family"=>"1", "priority"=>"", "result"=>"",
    "result_date"=>"", "result_digit"=>"", "result_json"=>"", "scheduled_date"=>"", "skipped_time"=>"", "state"=>"",
     "status"=>"not called", "updated_at"=>"#{Time.now.utc}", "voter_list_id"=>"#{voter_list.id}", "zip_code"=>""})
  end
  
  describe "abandon_call" do
    
    it "should change status" do
      voter = Factory(:voter)
      RedisVoter.abandon_call(voter.id)
      RedisVoter.read(voter.id)['status'].should eq(CallAttempt::Status::ABANDONED)  
    end
    
    it "should set callback to false" do
      voter = Factory(:voter)
      RedisVoter.abandon_call(voter.id)
      RedisVoter.read(voter.id)['call_back'].should eq("false")  
    end

    it "should set caller session to nil" do
      voter = Factory(:voter)
      RedisVoter.abandon_call(voter.id)
      RedisVoter.read(voter.id)['caller_session_id'].should eq("")
    end

    it "should set caller  to nil" do
      voter = Factory(:voter)
      RedisVoter.abandon_call(voter.id)
      RedisVoter.read(voter.id)['caller_id'].should eq("")
    end
    
    
  end

  describe "end_answered_call" do
    
    it "should set last call attempt time" do
      voter = Factory(:voter)
      RedisVoter.end_answered_call(voter.id)
      RedisVoter.read(voter.id)['last_call_attempt_time'].should_not be_nil 
    end
    
    it "should set caller session to nil" do
      voter = Factory(:voter)
      RedisVoter.end_answered_call(voter.id)
      RedisVoter.read(voter.id)['caller_session_id'].should eq("") 
    end
    
  end
  
  describe "answered_by_machine" do
    
    it "should set status" do
      voter = Factory(:voter)
      RedisVoter.answered_by_machine(voter.id, "status")
      RedisVoter.read(voter.id)['status'].should eq("status")      
    end
    
    it "should set caller_session as nil" do
      voter = Factory(:voter)
      RedisVoter.answered_by_machine(voter.id, "status")
      RedisVoter.read(voter.id)['caller_session_id'].should eq("")
    end
    
  end

  describe "set status" do
    
    it "should set status" do
      voter = Factory(:voter)
      RedisVoter.set_status(voter.id, "status")
      RedisVoter.read(voter.id)['status'].should eq("status")      
    end
    
  end

  describe "schedule_for_later" do
    
    it "should set status" do
      voter = Factory(:voter)
      RedisVoter.schedule_for_later(voter.id, Time.now)
      RedisVoter.read(voter.id)['status'].should eq(CallAttempt::Status::SCHEDULED)      
    end

    it "should set scheduled_date" do
      voter = Factory(:voter)
      RedisVoter.schedule_for_later(voter.id, Time.now)
      RedisVoter.read(voter.id)['scheduled_date'].should eq(Time.now.to_s)      
    end

    it "should set callback to true" do
      voter = Factory(:voter)
      RedisVoter.schedule_for_later(voter.id, Time.now)
      RedisVoter.read(voter.id)['call_back'].should eq("true")      
    end
    
    
  end

  describe "assigned_to_caller?" do
    
    it "should check id caller is assigned to voter" do
      RedisVoter.assign_to_caller(1, 1)
      RedisVoter.assigned_to_caller?(1).should eq(true)
    end
    
  end

end