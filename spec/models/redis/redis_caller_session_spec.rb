require "spec_helper"

describe RedisCallerSession do
  
  
  it "should read caller id" do
    caller_session = Factory(:webui_caller_session, caller_id: 123)
    RedisCallerSession.load_caller_session_info(caller_session.id, caller_session)
    RedisCallerSession.read(caller_session.id)["caller_id"].should eq("123")    
  end
  
  describe "start conference" do
      
    
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
