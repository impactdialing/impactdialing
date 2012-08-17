require "spec_helper"

describe RedisCallerSession do
  
  before(:each) do
    @redis = RedisConnection.call_flow_connection
  end
  
  
  it "should load caller session" do
    caller_session = Factory(:webui_caller_session)
    RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
    RedisCallerSession.read(caller_session.id).should eq({"attempt_in_progress"=>"", "available_for_call"=>"false", 
    "caller_id"=>"", "caller_number"=>"", "caller_type"=>"", "campaign_id"=>"", 
    "created_at"=>"#{Time.now.utc}", "debited"=>"false", "digit"=>"", "endtime"=>"", "id"=>"#{caller_session.id}", 
    "lock_version"=>"0", "on_call"=>"false", "payment_id"=>"", "question_id"=>"", "session_key"=>"", "sid"=>"", 
    "starttime"=>"", "state"=>"initial", "tAccountSid"=>"", "tCallSegmentSid"=>"", "tCalled"=>"", "tCaller"=>"", 
    "tDuration"=>"", "tEndTime"=>"", "tFlags"=>"", "tPhoneNumberSid"=>"", "tPrice"=>"", "tStartTime"=>"", "tStatus"=>"", 
    "type"=>"WebuiCallerSession", "updated_at"=>"#{Time.now.utc}", "voter_in_progress_id"=>""})
  end
  
  it "should read caller id" do
    caller_session = Factory(:webui_caller_session, caller_id: 123)
    RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
    RedisCallerSession.read(caller_session.id)["caller_id"].should eq("123")    
  end
  
  describe "start conference" do
  
    it "should set on call to true" do
      call_attempt = Factory(:call_attempt)
      caller_session = Factory(:webui_caller_session, on_call: true, available_for_call: false, attempt_in_progress: call_attempt)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisCallerSession.start_conference(caller_session.id)
      RedisCallerSession.read(caller_session.id)["on_call"].should eq('true')        
    end
    
    it "should set avaialable for call to true" do
      call_attempt = Factory(:call_attempt)
      caller_session = Factory(:webui_caller_session, on_call: true, available_for_call: false, attempt_in_progress: call_attempt)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisCallerSession.start_conference(caller_session.id)
      RedisCallerSession.read(caller_session.id)["available_for_call"].should eq('true')        
    end
    
    it "should set attempt in progress to nil" do
      call_attempt = Factory(:call_attempt)
      caller_session = Factory(:webui_caller_session, on_call: true, available_for_call: false, attempt_in_progress: call_attempt)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisCallerSession.start_conference(caller_session.id)      
      RedisCallerSession.read(caller_session.id)["attempt_in_progress"].should be_nil
    end    
  end
  
  describe "disconnected" do
    it "should return true if on call and avaialble is false" do
      call_attempt = Factory(:call_attempt)
      caller_session = Factory(:webui_caller_session, on_call: false, available_for_call: false, attempt_in_progress: call_attempt)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisCallerSession.disconnected?(caller_session.id).should be_true      
    end
    
    it "should return false if on call  is true" do
      call_attempt = Factory(:call_attempt)
      caller_session = Factory(:webui_caller_session, on_call: true, available_for_call: false, attempt_in_progress: call_attempt)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisCallerSession.disconnected?(caller_session.id).should be_false      
    end
    
    it "should return false if available_for_call is true" do
      call_attempt = Factory(:call_attempt)
      caller_session = Factory(:webui_caller_session, on_call: false, available_for_call: true, attempt_in_progress: call_attempt)
      RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
      RedisCallerSession.disconnected?(caller_session.id).should be_false      
    end
    
    
  end
  
end
