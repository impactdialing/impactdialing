require "spec_helper"

describe RedisVoter do
  

  
  
  describe "assigned_to_caller?" do
    
    it "should check id caller is assigned to voter" do
      RedisVoter.assign_to_caller(1, 1)
      RedisVoter.assigned_to_caller?(1).should eq(true)
    end
    
  end

  describe "assign_to_caller" do
    
    it "should assign caller session to voter" do
      RedisVoter.assign_to_caller(1, 1)
      RedisVoter.assigned_to_caller?(1).should eq(true)
    end
    
  end
  
  describe "connect_lead_to_caller" do
    
    it "should set caller id when caller session already assigned to voter" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, campaign: campaign)
      caller_session = Factory(:caller_session, caller_id: 1, campaign: campaign)
      call_attempt = Factory(:call_attempt, campaign: campaign, voter: voter)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisVoter.assign_to_caller(voter.id, caller_session.id)
      RedisCaller.should_not_receive(:longest_waiting_caller)
      RedisVoter.connect_lead_to_caller(voter.id, voter.campaign.id, call_attempt.id)
      RedisVoter.read(1)["caller_id"].should eq("1")
    end
    
    it "should set status as inprogress when caller session already assigned to voter" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, campaign: campaign)
      caller_session = Factory(:caller_session, caller_id: 1, campaign: campaign)
      call_attempt = Factory(:call_attempt, campaign: campaign, voter: voter)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisVoter.assign_to_caller(voter.id, caller_session.id)
      RedisCaller.should_not_receive(:longest_waiting_caller)
      RedisVoter.connect_lead_to_caller(voter.id, voter.campaign.id, call_attempt.id)
      RedisVoter.read(1)["status"].should eq(CallAttempt::Status::INPROGRESS)
    end
    
    it "should set caller as longest available if not already assigned" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, campaign: campaign)
      caller_session = Factory(:caller_session, caller_id: 2, campaign: campaign, available_for_call: true, on_call: true)
      call_attempt = Factory(:call_attempt, campaign: campaign, voter: voter)
      RedisCaller.add_caller(campaign.id, caller_session.id)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisVoter.connect_lead_to_caller(voter.id, campaign.id, call_attempt.id)
      RedisVoter.read(1)["caller_id"].should eq("2")
    end
    
    it "should set status as inprogress as longest available if not already assigned" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, campaign: campaign)
      caller_session = Factory(:caller_session, caller_id: 2, campaign: campaign, available_for_call: true, on_call: true)
      call_attempt = Factory(:call_attempt, campaign: campaign, voter: voter)
      RedisCaller.add_caller(campaign.id, caller_session.id)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisVoter.connect_lead_to_caller(voter.id, campaign.id, call_attempt.id)
      RedisVoter.read(1)["status"].should eq(CallAttempt::Status::INPROGRESS)
    end
    
    it "should move caller to on call list" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, campaign: campaign)
      caller_session = Factory(:caller_session, caller_id: 2, campaign: campaign, available_for_call: true, on_call: true)
      call_attempt = Factory(:call_attempt, campaign: campaign, voter: voter)
      RedisCaller.add_caller(campaign.id, caller_session.id)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisVoter.connect_lead_to_caller(voter.id, campaign.id, call_attempt.id)
      RedisCaller.on_call?(campaign.id, caller_session.id).should be_true
    end

    it "should set attempt in progress" do
      campaign = Factory(:campaign)
      voter = Factory(:voter, campaign: campaign)
      caller_session = Factory(:caller_session, caller_id: 2, campaign: campaign, available_for_call: true, on_call: true)
      call_attempt = Factory(:call_attempt, campaign: campaign, voter: voter)
      RedisCaller.add_caller(campaign.id, caller_session.id)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisVoter.connect_lead_to_caller(voter.id, campaign.id, call_attempt.id)
      RedisCallerSession.read(caller_session.id)['attempt_in_progress'].should eq(call_attempt.id.to_s)
    end
    
    
  end
  
  describe "could_not_connect_to_available_caller?" do
    
    it "should return true if caller not assigned to voter" do
      voter_list = Factory(:voter_list)
      campaign = Factory(:campaign)
      voter = Factory(:voter, voter_list: voter_list, FirstName: "abc", caller_session: nil, campaign: campaign)
      RedisVoter.load_voter_info(voter.id, voter)
      RedisVoter.voter(voter.id).delete('caller_session_id')      
      RedisVoter.could_not_connect_to_available_caller?(campaign.id, voter.id).should be_true
    end
    
    it "should return true if caller is assigned to voter but caller is disonnected" do
      caller = Factory(:caller)
      caller_session = Factory(:caller_session, caller_id: caller.id, available_for_call: false, on_call: false)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisCaller.add_caller(1, caller_session.id)
      RedisCaller.disconnect_caller(1, caller_session.id)
      voter_list = Factory(:voter_list)
      voter = Factory(:voter, voter_list: voter_list, FirstName: "abc", caller_session: caller_session)
      RedisVoter.load_voter_info(voter.id, voter)      
      RedisVoter.assign_to_caller(voter.id, caller_session.id)
      RedisVoter.could_not_connect_to_available_caller?(1, voter.id).should be_true
    end
    
    it "should return false if caller is assigned to voter but caller is connected" do
      caller = Factory(:caller)
      caller_session = Factory(:caller_session, caller_id: caller.id, available_for_call: true, on_call: true)
      RedisCaller.add_caller(1, caller_session.id)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      voter_list = Factory(:voter_list)
      voter = Factory(:voter, voter_list: voter_list, FirstName: "abc")
      RedisVoter.load_voter_info(voter.id, voter)      
      RedisVoter.assign_to_caller(voter.id, caller_session.id)
      RedisVoter.could_not_connect_to_available_caller?(1, voter.id).should be_false
    end
    
    
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
      RedisVoter.read(voter.id)['caller_session_id'].should be_nil
    end

    it "should set caller  to nil" do
      voter = Factory(:voter)
      RedisVoter.abandon_call(voter.id)
      RedisVoter.read(voter.id)['caller_id'].should be_nil
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
      RedisVoter.read(voter.id)['caller_session_id'].should be_nil
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
      RedisVoter.read(voter.id)['caller_session_id'].should be_nil
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

  

end