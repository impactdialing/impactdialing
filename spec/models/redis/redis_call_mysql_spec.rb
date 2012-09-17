require "spec_helper"

describe RedisCallMysql do
  
  describe "call completed" do
    
    it "should update call attempt" do
      caller_session = Factory(:caller_session)
      call_attempt = Factory(:call_attempt, voter: Factory(:voter), caller_session: caller_session)      
      RedisCallAttempt.load_call_attempt_info(call_attempt.id, call_attempt)
      RedisCallAttempt.connect_call(call_attempt.id, 1, caller_session.id)
      RedisCallAttempt.disconnect_call(call_attempt.id, "abc", "def")
      RedisCallAttempt.end_answered_call(call_attempt.id)
      RedisCallAttempt.wrapup(call_attempt.id)
      RedisCallMysql.call_completed(call_attempt.id)
      call_attempt.reload
      call_attempt.connecttime.should_not be_nil
      call_attempt.call_end.should_not be_nil
      call_attempt.status.should eq('Call completed with success.')      
    end    
    
    it "should update voter" do
      caller_session = Factory(:caller_session)
      voter = Factory(:voter)
      call_attempt = Factory(:call_attempt, voter: voter, caller_session: caller_session)
      RedisVoter.load_voter_info(voter.id, voter)
      RedisVoter.assign_to_caller(voter.id, caller_session.id) 
      RedisVoter.end_answered_call(voter.id)
      
      call_attempt.reload
      call_attempt.connecttime.should_not be_nil
      call_attempt.call_end.should_not be_nil
      call_attempt.status.should eq('Call completed with success.')      
    end    
    
  end
  
end