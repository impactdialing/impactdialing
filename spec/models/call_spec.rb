require "spec_helper"

describe Call do
  
  it "should start a call in initial state" do
    call = Factory(:call)
    call.state.should eq('initial')
  end
  
  describe "incoming call answered by human" do
    let(:caller) {Factory(:caller)}
    let(:caller_session) { Factory(:caller_session, caller: caller, on_call: true, available_for_call: true) }
    let(:voter) { Factory(:voter, caller_session: caller_session) }
    let(:call_attempt) { Factory(:call_attempt, voter: voter) }
        
    it "should move to the connected state" do
      call = Factory(:call, answered_by: "human", call_attempt: call_attempt)
      call.incoming_call!
      call.state.should eq('connected')
    end
    
    it "should update connecttime" do
      call = Factory(:call, answered_by: "human", call_attempt: call_attempt)
      call.incoming_call!
      call.call_attempt.connecttime.should_not be_nil  
    end
    
    it "should update update call attempt status to inprogress" do
      call = Factory(:call, answered_by: "human", call_attempt: call_attempt)
      call.incoming_call!
      call.call_attempt.status.should eq(CallAttempt::Status::INPROGRESS)  
    end
    
    it "should update  voters caller id" do
      call = Factory(:call, answered_by: "human", call_attempt: call_attempt)
      call.incoming_call!
      call.call_attempt.voter.caller_id.should eq(caller.id)  
    end
    
    it "should update caller session to not available for call" do
      call = Factory(:call, answered_by: "human", call_attempt: call_attempt)
      call.incoming_call!
      call.call_attempt.voter.caller_session.available_for_call.should be_false  
    end    
  end
  
  describe "incoming call answered by human that need to be abandones" do
    let(:caller) {Factory(:caller)}
    let(:caller_session) { Factory(:caller_session, caller: caller, on_call: false, available_for_call: false) }
    let(:voter) { Factory(:voter, caller_session: caller_session) }
    let(:call_attempt) { Factory(:call_attempt, voter: voter) }
        
    it "should move to the connected state" do
      call = Factory(:call, answered_by: "human", call_attempt: call_attempt)
      call.incoming_call!
      call.state.should eq('connected')
    end
    
    it "should change call_attempt status to abandoned" do
      call = Factory(:call, answered_by: "human", call_attempt: call_attempt)
      call.incoming_call!
      call.call_attempt.status.should eq(CallAttempt::Status::ABANDONED)  
    end
    
    it "should return hangup twiml for abandoned users" do
      call = Factory(:call, answered_by: "human", call_attempt: call_attempt)
      call.incoming_call!.should eq('')
    end
    
    
    
  end
  
  
end