require "spec_helper"

describe Call do

  it "should start a call in initial state" do
    call = Factory(:call)
    call.state.should eq('initial')
  end

  describe "initial" do

    describe "incoming call answered by human" do

      before(:each) do
        @caller = Factory(:caller)
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @voter  = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
      end

      it "should move to the connected state" do
        call = Factory(:call, call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")
        call.incoming_call!
        call.state.should eq('connected')
      end

      it "should update connecttime" do
        call = Factory(:call, call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")
        call.incoming_call!
        call.call_attempt.connecttime.should_not be_nil
      end

      it "should update voters caller id" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected") 
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")               
        call.incoming_call!
        call.call_attempt.voter.caller_id.should eq(@caller.id)
      end

      it "should update voters status to inprogress" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")        
        call.incoming_call!
        call.call_attempt.voter.status.should eq(CallAttempt::Status::INPROGRESS)
      end

      it "should update voters caller_session" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")        
        call.incoming_call!
        call.call_attempt.voter.caller_session.should eq(@caller_session)
      end


      it "should update  call attempt status to inprogress" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")        
        call.incoming_call!
        call.call_attempt.status.should eq(CallAttempt::Status::INPROGRESS)
      end

      it "should update  call attempt connecttime" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected") 
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")               
        call.incoming_call!
        call.call_attempt.connecttime.should_not be_nil
      end


      it "should assign caller_session  to call attempt" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")  
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")              
        call.incoming_call!
        call.call_attempt.caller_session.should eq(@caller_session)
      end


      it "should update caller session to not available for call" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")   
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")             
        call.incoming_call!
        call.call_attempt.voter.caller_session.available_for_call.should be_false
      end

      it "should move to connected state when voter is already assigned caller session" do
        @voter.update_attribute(:caller_session, @caller_session)
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")   
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")             
        call.incoming_call!
        call.call_attempt.voter.caller_session.available_for_call.should be_false
      end


      it "should start a conference in connected state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")      
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")  
        call.incoming_call!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"https://#{Settings.twilio_callback_host}/calls/#{call.id}/flow?event=disconnect\" record=\"false\"><Conference waitUrl=\"hold_music\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\" maxParticipants=\"2\"></Conference></Dial></Response>")
      end
    end

    describe "incoming call answered by human that need to be abandoned" do
      before(:each) do
        @caller = Factory(:caller)
        @script = Factory(:script)
        @campaign =  Factory(:predictive, script: @script)
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

      it "should update call_attempt connecttime " do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        call.incoming_call!
        call.call_attempt.connecttime.should_not be_nil
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
        @campaign =  Factory(:preview, script: @script, use_recordings: false)
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

      it "should move to state call_answered_by_machine" do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
        @campaign.update_attribute(:use_recordings, true)
        call.incoming_call!
        call.state.should eq('call_answered_by_machine')

      end

      it "should render the user recording and hangup if user recording present" do
        recording = Factory(:recording)
        @campaign.update_attribute(:recording, recording)
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
        @campaign.update_attribute(:use_recordings, true)
        call.incoming_call!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Play>http://s3.amazonaws.com/impactdialing_production/test/uploads/unknown/#{recording.id}.mp3</Play><Hangup/></Response>")
      end

      it "should render  and hangup if user recording is not present" do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
        call.incoming_call!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end

    end



  end

  describe "connected" do

     describe "hangup "  do
       before(:each) do
         @script = Factory(:script)
         @campaign =  Factory(:campaign, script: @script)
         @voter = Factory(:voter, campaign: @campaign)
         @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
       end

       it "should render nothing" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         @call_attempt.should_receive(:end_running_call)
         call.hangup!
         call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response></Response>")
       end

       it "should move to hungup state" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         @call_attempt.should_receive(:end_running_call)
         call.hangup!
         call.state.should eq('hungup')
       end
     end

     describe "disconnect"  do
       before(:each) do
         @script = Factory(:script)
         @campaign =  Factory(:campaign, script: @script)
         @caller_session = Factory(:caller_session)
         @voter = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
         @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
       end


       it "should update call attempt recording_duration" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected', recording_duration: 4)
         Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
         Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")         
         call.disconnect!
         call.call_attempt.recording_duration.should eq(4)
       end

       it "should update call attempt recording_url" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected', recording_duration: 4, recording_url: "url")
         Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
         Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")                  
         call.disconnect!
         call.call_attempt.recording_url.should eq("url")
       end

       it "should move to disconnected state" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
         Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")                  
         call.disconnect!
         call.state.should eq('disconnected')

       end

       it "should hangup twiml" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
         Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")                  
         call.disconnect!
         call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
       end

     end


  end

  describe "hungup" do

    describe "disconnect call" do
      before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @caller_session = Factory(:caller_session)
       @voter = Factory(:voter, campaign: @campaign, caller_session: @caller_session)

       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      end


      it "should update call attempt status as success" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
       Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")         
       call.disconnect!
       call.call_attempt.status.should eq(CallAttempt::Status::SUCCESS)
      end

      it "should update call attempt recording_duration" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup', recording_duration: 4)
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
       Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")                
       call.disconnect!
       call.call_attempt.recording_duration.should eq(4)
      end

      it "should update call attempt recording_url" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup', recording_duration: 4, recording_url: "url")
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
       Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")         
       call.disconnect!
       call.call_attempt.recording_url.should eq("url")
      end

      it "should change status to disconnected" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
       Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")                
       call.disconnect!
       call.state.should eq("disconnected")
      end

      it "should hangup twiml" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
       Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")                
       call.disconnect!
       call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end

    end

  end

  describe "call_answered_by_machine" do

    describe "call_ended for answered by machine" do

      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
        @voter = Factory(:voter, campaign: @campaign)
        @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, status: CallAttempt::Status::HANGUP)
      end

      it "should should update wrapup time" do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'call_answered_by_machine')
        call.call_ended!
        call.call_attempt.wrapup_time.should_not be_nil
      end

      it "should  update voters last_call_attempt_time" do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'call_answered_by_machine')
        call.call_ended!
        call.voter.last_call_attempt_time.should_not be_nil
      end

      it "should  update voters call_back" do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'call_answered_by_machine')
        call.call_ended!
        call.voter.call_back.should be_false
      end

      it "should  return hangup twiml" do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'call_answered_by_machine')
        call.call_ended!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end


  end

  describe "call_answered_by_lead" do
    describe "submit_result" do

      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
        @voter = Factory(:voter, campaign: @campaign)
        @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      end

      it "should wrapup call_attempt" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', all_states: "")
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @caller_session.id)
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_voter_event_moderator")
        call.submit_result!
        call.call_attempt.wrapup_time.should_not be_nil
      end
    end

    describe "submit_result_and_stop" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
        @voter = Factory(:voter, campaign: @campaign)
        @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      end

      it "should wrapup call_attempt" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', all_states: "")
        call.submit_result_and_stop!
        call.call_attempt.wrapup_time.should_not be_nil
      end
    end
  end

end