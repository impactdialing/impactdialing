require "spec_helper"

describe Call do
  
  it "should start a call in initial state" do
    call = Factory(:call)
    call.state.should eq('initial')
  end
  
  describe "incoming call answered by human" do
    
    before(:each) do
      @caller = Factory(:caller)
      @script = Factory(:script)
      @campaign =  Factory(:campaign, script: @script)    
      @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
      @voter  = Factory(:voter, campaign: @campaign)
      @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
    end
        
    it "should move to the connected state" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.state.should eq('connected')
    end
    
    it "should update connecttime" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.connecttime.should_not be_nil  
    end
    
    it "should update voters caller id" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.caller_id.should eq(@caller.id)  
    end
    
    it "should update voters status to inprogress" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.status.should eq(CallAttempt::Status::INPROGRESS)  
    end
    
    it "should update voters caller_session" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.caller_session.should eq(@caller_session)
    end
            
    
    it "should update  call attempt status to inprogress" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.status.should eq(CallAttempt::Status::INPROGRESS)  
    end
    
    it "should update  call attempt connecttime" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.connecttime.should_not be_nil
    end
    
    it "should update  call attempt call_start time" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.call_start.should_not be_nil
    end
    
    it "should assign caller_session  to call attempt" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.caller_session.should eq(@caller_session)
    end
    
    
    it "should update caller session to not available for call" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.caller_session.available_for_call.should be_false  
    end    
    
    it "should move to connected state when voter is already assigned caller session" do
      @voter.update_attribute(:caller_session, @caller_session)
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.caller_session.available_for_call.should be_false  
    end    
    
        
    it "should start a conference in connected state" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!  
      call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"/call_attempts/#{call.call_attempt.id}/disconnect\" record=\"false\"><Conference waitUrl=\"https://3ngz.localtunnel.com/hold_call\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\" maxParticipants=\"2\"></Conference></Dial></Response>")      
    end
  end
  
  describe "incoming call answered by human that need to be abandoned" do
    before(:each) do
      @caller = Factory(:caller)
      @script = Factory(:script)
      @campaign =  Factory(:campaign, script: @script)          
      @caller_session = Factory(:caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign)
      @voter = Factory(:voter, campaign: @campaign)
      @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
    end
        
    it "should move to the abandoned state" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.state.should eq('abandoned')
    end
    
    it "should change call_attempt status to abandoned" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.status.should eq(CallAttempt::Status::ABANDONED)  
    end
    
    it "should update call_attempt wrapup time" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.wrapup_time.should_not be_nil
    end
    
    it "should update call_attempt wrapup time" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.wrapup_time.should_not be_nil
    end
    
    it "should change voter status to abandoned" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.status.should eq(CallAttempt::Status::ABANDONED)  
    end
    
    it "should update voter call_back to false" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.call_back.should be_false
    end
    
    it "should update voter caller_session to nil" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.caller_session.should be_nil
    end
    
    it "should update voter caller_id to nil" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.caller_id.should be_nil
    end
        
    it "should return hangup twiml for abandoned users" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
      call.incoming_call!
      call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end        
  end
  
  describe "incoming call answered by machine" do
    
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:campaign, script: @script, use_recordings: false)          
      @voter = Factory(:voter, campaign: @campaign)
      @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
    end
        
    it "should  update connecttime for call_attempt" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.connecttime.should_not be_nil      
    end
    
    it "should  update wrapup for call_attempt" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.wrapup_time.should_not be_nil      
    end
    
    it "should  update call_end for call_attempt" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.call_end.should_not be_nil      
    end
    
    it "should  update call_attempt status to hangup if no user recording" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.status.should eq(CallAttempt::Status::HANGUP)
    end
    
    it "should update call_attempt status to voicemail if user recording present" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      @campaign.update_attribute(:use_recordings, true)
      call.incoming_call!
      call.call_attempt.status.should eq(CallAttempt::Status::VOICEMAIL)
    end
    
    it "should  update voter status to hangup if no user recording" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      call.incoming_call!
      call.call_attempt.voter.status.should eq(CallAttempt::Status::HANGUP)
    end
    
    it "should update voter status to voicemail if user recording present" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      @campaign.update_attribute(:use_recordings, true)
      call.incoming_call!
      call.call_attempt.voter.status.should eq(CallAttempt::Status::VOICEMAIL)
    end
    
    it "should set voter caller session to nil" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      @campaign.update_attribute(:use_recordings, true)
      call.incoming_call!
      call.call_attempt.voter.caller_session.should be_nil
    end
    
    it "should render the user recording and hangup if user recording present" do
      @campaign.update_attribute(:recording, Factory(:recording))
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      @campaign.update_attribute(:use_recordings, true)
      call.incoming_call!
      call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Play>http://s3.amazonaws.com/impactdialing_production/test/uploads/unknown/8.mp3</Play><Hangup/></Response>")      
    end
    
    it "should render  and hangup if user recording is not present" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
      call.incoming_call!
      call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")      
    end
    
    
  end    
    
    
  
  
  
end