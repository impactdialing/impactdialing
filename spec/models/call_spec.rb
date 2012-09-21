require "spec_helper"

describe Call do

  it "should start a call in initial state" do
    call = Factory(:call)
    call.state.should eq('initial')
  end

  describe "initial" do

    describe "incoming call answered by human" do

<<<<<<< HEAD
        before(:each) do
          @caller = Factory(:caller)
          @script = Factory(:script)
          @campaign =  Factory(:preview, script: @script)
          @caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
          @voter  = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
          @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
        end
      
        it "should move to the connected state" do
          call = Factory(:call, call_attempt: @call_attempt, call_status: 'in-progress')
          @call_attempt.should_receive(:connect_call)
          @call_attempt.should_receive(:publish_voter_connected)
          call.incoming_call!
          call.state.should eq('connected')
        end
      
        it "should start a conference in connected state" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
          @call_attempt.should_receive(:connect_call)
          @call_attempt.should_receive(:caller_session_key)
          @call_attempt.should_receive(:redis_caller_session).and_return("1")

          @call_attempt.should_receive(:publish_voter_connected)
          call.incoming_call!
          call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"https://#{Settings.host}/calls/#{call.id}/flow?event=disconnect\" record=\"false\"><Conference waitUrl=\"hold_music\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\" maxParticipants=\"2\"/></Dial></Response>")
        end


=======
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
        call.incoming_call!
        call.state.should eq('connected')
      end

      it "should update connecttime" do
        call = Factory(:call, call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")
        call.incoming_call!
        call.call_attempt.connecttime.should_not be_nil
      end

      it "should update voters caller id" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.call_attempt.voter.caller_id.should eq(@caller.id)
      end

      it "should update voters status to inprogress" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.call_attempt.voter.status.should eq(CallAttempt::Status::INPROGRESS)
      end

      it "should update voters caller_session" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.call_attempt.voter.caller_session.should eq(@caller_session)
      end


      it "should update  call attempt status to inprogress" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.call_attempt.status.should eq(CallAttempt::Status::INPROGRESS)
      end

      it "should update  call attempt connecttime" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.call_attempt.connecttime.should_not be_nil
      end


      it "should assign caller_session  to call attempt" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.call_attempt.caller_session.should eq(@caller_session)
      end


      it "should update caller session to not available for call" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.call_attempt.voter.caller_session.available_for_call.should be_false
      end

      it "should move to connected state when voter is already assigned caller session" do
        @voter.update_attribute(:caller_session, @caller_session)
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.call_attempt.voter.caller_session.available_for_call.should be_false
      end


      it "should start a conference in connected state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt)
        Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_connected")        
        call.incoming_call!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"https://#{Settings.host}/calls/#{call.id}/flow?event=disconnect\" record=\"false\"><Conference waitUrl=\"hold_music\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\" maxParticipants=\"2\"></Conference></Dial></Response>")
>>>>>>> em
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
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
          @call_attempt.should_receive(:caller_available?).and_return(false)
          @call_attempt.should_receive(:caller_not_available?).and_return(true)
          @call_attempt.should_receive(:abandon_call)
          @call_attempt.should_receive(:redirect_caller)
          call.incoming_call!
          call.state.should eq('abandoned')
        end
      
        it "should return hangup twiml for abandoned users" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
          @call_attempt.should_receive(:caller_available?).and_return(false)
          @call_attempt.should_receive(:caller_not_available?).and_return(true)
          @call_attempt.should_receive(:abandon_call)
          @call_attempt.should_receive(:redirect_caller)
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


        it "should move to state call_answered_by_machine" do
          call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
          @campaign.update_attribute(:use_recordings, true)
          @call_attempt.should_receive(:process_answered_by_machine)
          @call_attempt.should_receive(:redirect_caller)      
          call.incoming_call!
          call.state.should eq('call_answered_by_machine')
        end

        it "should render the user recording and hangup if user recording present" do
          recording = Factory(:recording)
          @campaign.update_attributes(recording_id: recording.id, use_recordings: true)
          call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
          @call_attempt.should_receive(:process_answered_by_machine)
          @call_attempt.should_receive(:redirect_caller)            
          call.incoming_call!
          call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Play>http://s3.amazonaws.com/impactdialing_production/test/uploads/unknown/#{recording.id}.mp3</Play><Hangup/></Response>")
        end

        it "should render  and hangup if user recording is not present" do
          call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
          call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
          @call_attempt.should_receive(:process_answered_by_machine)
          @call_attempt.should_receive(:redirect_caller)                  
          call.incoming_call!
          call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
        end

      end
   
    describe "twilio detecting real user as answering machine" do
      before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @voter = Factory(:voter, campaign: @campaign)
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
      end

      it "should update wrapuptime for call attempt" do
       call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, call_status: "success")
       call.call_ended!
       call.state.should eq('abandoned')
      end


      it "should should render hangup to the lead" do
       call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, call_status: "success")
       call.call_ended!
       call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end
  
    describe "end call that dint connect" do

        before(:each) do
         @script = Factory(:script)
         @campaign =  Factory(:campaign, script: @script)
         @caller = Factory(:caller)
         @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
         @voter = Factory(:voter, campaign: @campaign)
         @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
        end

<<<<<<< HEAD
        it "should update call attempt status" do            
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'busy', state: "initial")
          @call_attempt.should_receive(:end_unanswered_call)
          @call_attempt.should_receive(:redirect_caller)
=======
        it "should update call attempt status" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'busy')
          Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
          call.call_ended!
          call.call_attempt.status.should eq('No answer busy signal')
        end

        it "should update wrapup time" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'failed')
          Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
          call.call_ended!
          call.call_attempt.wrapup_time.should_not be_nil
        end

        it "should set callers voter to nil" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'no-answer')
          Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
          call.call_ended!
          call.caller_session.voter_in_progress.should be_nil
        end

        it "should set voters status to nil" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'no-answer')
          Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
          call.call_ended!
          call.call_attempt.voter.status.should eq('No answer')
        end

        it "should set voters last attempt time" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt,  call_status: 'no-answer')
          Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
>>>>>>> em
          call.call_ended!
          call.state.should eq('call_not_answered_by_lead')
        end

<<<<<<< HEAD
=======
        it "should set voters callback as false" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'no-answer')
          Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
          call.call_ended!
          call.call_attempt.voter.call_back.should be_false
        end
>>>>>>> em
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

<<<<<<< HEAD
   describe "disconnect"  do
     before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @caller_session = Factory(:caller_session)
       @voter = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
     end
     
=======
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
         call.disconnect!
         call.call_attempt.recording_duration.should eq(4)
       end

       it "should update call attempt recording_url" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected', recording_duration: 4, recording_url: "url")
         Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
         call.disconnect!
         call.call_attempt.recording_url.should eq("url")
       end
>>>>>>> em

       it "should move to disconnected state" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
         call.disconnect!
         call.state.should eq('disconnected')

       end


       it "should hangup twiml" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
<<<<<<< HEAD
         @call_attempt.should_receive(:disconnect_call)
         @call_attempt.should_receive(:publish_voter_disconnected)
=======
         Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
>>>>>>> em
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


<<<<<<< HEAD
      it "should change status to disconnected" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       @call_attempt.should_receive(:disconnect_call)
       @call_attempt.should_receive(:publish_voter_disconnected)
=======
      it "should update call attempt status as success" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
       call.disconnect!
       call.call_attempt.status.should eq(CallAttempt::Status::SUCCESS)
      end

      it "should update call attempt recording_duration" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup', recording_duration: 4)
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
       call.disconnect!
       call.call_attempt.recording_duration.should eq(4)
      end

      it "should update call attempt recording_url" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup', recording_duration: 4, recording_url: "url")
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
       call.disconnect!
       call.call_attempt.recording_url.should eq("url")
      end

      it "should change status to disconnected" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
>>>>>>> em
       call.disconnect!
       call.state.should eq("disconnected")
      end
  
      it "should hangup twiml" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
<<<<<<< HEAD
       @call_attempt.should_receive(:disconnect_call)       
       @call_attempt.should_receive(:publish_voter_disconnected)
=======
       Resque.should_receive(:enqueue).with(CallPusherJob, @call_attempt.id, "publish_voter_disconnected")
>>>>>>> em
       call.disconnect!
       call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end  
    end
  
  end
  
  describe "disconnected" do
  
    describe "call_answered_by_lead" do
      before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @voter = Factory(:voter, campaign: @campaign)
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
      end
      
      it "should update call end time" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'success')
        call.call_ended!
        call.state.should eq("call_answered_by_lead")
      end
  
      it "should return hangup twmil" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'success')
        call.call_ended!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
  
    end
  
    describe "call not answered by lead" do
      before(:each) do
       @script = Factory(:script)
       @campaign =  Factory(:campaign, script: @script)
       @voter = Factory(:voter, campaign: @campaign)
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)
      end
  
  
      it "should update call status" do
        call = Factory(:call, call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
<<<<<<< HEAD
        @call_attempt.should_receive(:end_unanswered_call)
        @call_attempt.should_receive(:redirect_caller)
=======
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
>>>>>>> em
        call.call_ended!
        call.state.should eq("call_not_answered_by_lead")
      end
<<<<<<< HEAD
  
      it "should render hangup twiml" do
        call = Factory(:call, call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        @call_attempt.should_receive(:end_unanswered_call)
        @call_attempt.should_receive(:redirect_caller)
        call.call_ended!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
=======

      it "should update voters status" do
        call = Factory(:call, call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.voter.status.should eq('No answer busy signal')
      end

      it "should update voters last_call_attempt_time" do
        call = Factory(:call, call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.voter.last_call_attempt_time.should_not be_nil
      end

      it "should update voters callback as false" do
        call = Factory(:call, call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.voter.call_back.should be_false
>>>>>>> em
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
  
  
      it "should  update call state " do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'call_answered_by_machine')
        @call_attempt.should_receive(:end_answered_by_machine)
        call.call_ended!
        call.state.should eq('call_end_machine')
      end
  
      it "should  return hangup twiml" do
        call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'call_answered_by_machine')
        @call_attempt.should_receive(:end_answered_by_machine)
        call.call_ended!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end
<<<<<<< HEAD
  
=======

    describe "call_ended not answered machine" do

      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
        @voter = Factory(:voter, campaign: @campaign)
        @caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      end

      it "should should update wrapup time" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.call_attempt.wrapup_time.should_not be_nil
      end

      it "should update status" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.call_attempt.status.should eq(CallAttempt::Status::BUSY)
      end

      it "should  update voters last_call_attempt_time" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.voter.last_call_attempt_time.should_not be_nil
      end

      it "should  update voters call_back" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.voter.call_back.should be_false
      end

      it "should  update voters status" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.voter.status.should eq(CallAttempt::Status::BUSY)
      end


      it "should  return hangup twiml" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', call_status: 'busy')
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
        call.call_ended!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end

>>>>>>> em
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
  
      it "should update call state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'call_answered_by_lead', all_states: "")
<<<<<<< HEAD
        @call_attempt.should_receive(:wrapup_now)
        @call_attempt.should_receive(:redirect_caller)
=======
        Resque.should_receive(:enqueue).with(ModeratorCallJob, @call_attempt.id, "publish_moderator_response_submited")
        Resque.should_receive(:enqueue).with(RedirectCallerJob, @call_attempt.id)
>>>>>>> em
        call.submit_result!
        call.state.should eq('wrapup_and_continue')
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
      
      it "should update call state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'call_answered_by_lead', all_states: "")
        @call_attempt.should_receive(:wrapup_now)
        @call_attempt.should_receive(:end_caller_session)
        call.submit_result_and_stop!
        call.state.should eq('wrapup_and_stop')
      end
    end
  end

end