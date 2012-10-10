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
        @campaign =  Factory(:predictive, script: @script)
        @voter  = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
        @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)        
        @caller_session = Factory(:webui_caller_session, caller: @caller, campaign: @campaign, voter_in_progress: @voter, attempt_in_progress: @call_attempt, on_call: true, available_for_call: false, state: "connected")
      end

      it "should move to the connected state" do
        call = Factory(:call, call_attempt: @call_attempt, call_status: 'in-progress', state: 'initial')
        # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["connected", @campaign.id, @call_attempt.id, @caller_session.id])
        call.incoming_call!
        call.state.should eq('connected')
      end


      it "should start a conference in connected state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
        # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["connected", @campaign.id, @call_attempt.id, @caller_session.id])
        call.incoming_call!
        call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"https://#{Settings.twilio_callback_host}/calls/#{call.id}/flow?event=disconnect\" record=\"false\"><Conference waitUrl=\"hold_music\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\" maxParticipants=\"2\"/></Dial></Response>")
      end
    end


    describe "incoming call answered by human that need to be abandoned" do
        before(:each) do
          @caller = Factory(:caller)
          @script = Factory(:script)
          @campaign =  Factory(:predictive, script: @script)
          @voter  = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
          @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign)        
          @caller_session = Factory(:webui_caller_session, caller: @caller, campaign: @campaign, voter_in_progress: @voter, attempt_in_progress: @call_attempt, state: "conference_ended")
        end
  
        it "should move to the abandoned state" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
          RedisCall.should_receive(:push_to_abandoned_call_list).with(call.attributes); 
          # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["abandoned", @campaign.id, @call_attempt.id, nil])
          @call_attempt.should_receive(:redirect_caller)
          call.incoming_call!
          call.state.should eq('abandoned')
        end
      
        it "should return hangup twiml for abandoned users" do
          call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
          RedisCall.should_receive(:push_to_abandoned_call_list).with(call.attributes); 
          # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["abandoned", @campaign.id, @call_attempt.id, nil])
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
          RedisCall.should_receive(:push_to_processing_by_machine_call_hash).with(call.attributes);
          # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["answered_machine", @campaign.id, @call_attempt.id, nil])
          @call_attempt.should_receive(:redirect_caller)      
          call.incoming_call!
          call.state.should eq('call_answered_by_machine')
        end

        it "should render the user recording and hangup if user recording present" do
          recording = Factory(:recording)
          @campaign.update_attributes(recording_id: recording.id, use_recordings: true)
          call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
          RedisCall.should_receive(:push_to_processing_by_machine_call_hash).with(call.attributes);
          # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["answered_machine", @campaign.id, @call_attempt.id, nil])
          @call_attempt.should_receive(:redirect_caller)      
          call.incoming_call!
          call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Play>http://s3.amazonaws.com/impactdialing_production/test/uploads/unknown/#{recording.id}.mp3</Play><Hangup/></Response>")
        end

        it "should render  and hangup if user recording is not present" do
          call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt)
          RedisCall.should_receive(:push_to_processing_by_machine_call_hash).with(call.attributes);
          # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["answered_machine", @campaign.id, @call_attempt.id, nil])
          @call_attempt.should_receive(:redirect_caller)      
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
         @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, sid: "abc")
       end
  
       it "should render nothing" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         @call_attempt.should_receive(:enqueue_call_flow).with(EndRunningCallJob, [@call_attempt.sid])
         call.hangup!
         call.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response></Response>")
       end
  
       it "should move to hungup state" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         @call_attempt.should_receive(:enqueue_call_flow).with(EndRunningCallJob, [@call_attempt.sid])
         call.hangup!
         call.state.should eq('hungup')
       end
     end

     describe "disconnect"  do
       before(:each) do
         @script = Factory(:script)
         @campaign =  Factory(:campaign, script: @script)
         @caller = Factory(:caller)
         @caller_session = Factory(:caller_session, caller: @caller)
         @voter = Factory(:voter, campaign: @campaign, caller_session: @caller_session)
         @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
       end

       it "should move to disconnected state" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         RedisCall.should_receive(:push_to_disconnected_call_list).with(call.attributes.merge("caller_id"=>@caller.id))
         # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["disconnected", @campaign.id, @call_attempt.id, @caller_session.id])
         @call_attempt.should_receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])
         call.disconnect!
         call.state.should eq('disconnected')
       end


       it "should hangup twiml" do
         call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
         RedisCall.should_receive(:push_to_disconnected_call_list).with(call.attributes.merge("caller_id"=>@caller.id))
         # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["disconnected", @campaign.id, @call_attempt.id, @caller_session.id])
         @call_attempt.should_receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])
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
       @caller = Factory(:caller)
       @caller_session = Factory(:caller_session, caller: @caller)
       @voter = Factory(:voter, campaign: @campaign, caller_session: @caller_session)  
       @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      end

      it "should change status to disconnected" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       RedisCall.should_receive(:push_to_disconnected_call_list).with(call.attributes.merge("caller_id"=>@caller.id))
       # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["disconnected", @campaign.id, @call_attempt.id, @caller_session.id])
       @call_attempt.should_receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])       
       call.disconnect!
       call.state.should eq("disconnected")
      end
  
      it "should hangup twiml" do
       call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       RedisCall.should_receive(:push_to_disconnected_call_list).with(call.attributes.merge("caller_id"=>@caller.id))
       # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["disconnected", @campaign.id, @call_attempt.id, @caller_session.id])
       @call_attempt.should_receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])       
       call.disconnect!
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
      it "should update call state" do
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected', all_states: "")
        RedisCall.should_receive(:push_to_wrapped_up_call_list).with(@call_attempt.attributes.merge(caller_type: CallerSession::CallerType::TWILIO_CLIENT));
        # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["wrapped_up", @campaign.id, @call_attempt.id, @caller_session.id])
        @call_attempt.should_receive(:redirect_caller)
        call.submit_result!
        call.state.should eq("wrapup_and_continue")
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
        call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected')
        RedisCall.should_receive(:push_to_wrapped_up_call_list).with(@call_attempt.attributes.merge(caller_type: CallerSession::CallerType::TWILIO_CLIENT));
        # @call_attempt.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["wrapped_up", @campaign.id, @call_attempt.id, @caller_session.id])
        @call_attempt.should_receive(:end_caller_session)
        call.submit_result_and_stop!
        call.state.should eq('wrapup_and_stop')        
      end
      
    end
  end
  
  describe "state machine methods" do
    it "should return answered by machine" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'disconnected')
      call.answered_by_machine?.should be_true
    end
    
    it "should return answered by human" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected')
      call.answered_by_human?.should be_true
    end
    
    describe "answered_by_human_and_caller_available?"
    
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:campaign, script: @script)
      @voter = Factory(:voter, campaign: @campaign)
      @call_attempt = Factory(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      @caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, attempt_in_progress: @call_attempt, state: "connected")      
    end
    
    it "should return answered_by_human_and_caller_available?" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      call.answered_by_human_and_caller_available?.should be_true
    end
    
    it "should return false if not answered by human" do
      call = Factory(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      call.answered_by_human_and_caller_available?.should be_false
    end
    
    it "should return false if call status is not in progress" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "completed")
      call.answered_by_human_and_caller_available?.should be_false
    end
    
    it "should return false if caller session is nil" do
      @caller_session.update_attributes(attempt_in_progress: nil)
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      call.answered_by_human_and_caller_available?.should be_false
    end
    
    it "should return false if caller session is not available" do
      @caller_session.update_attributes(on_call: false)
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      call.answered_by_human_and_caller_available?.should be_false
    end
    
    it "should return true if caller session is nil" do
      @caller_session.update_attributes(attempt_in_progress: nil)
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      call.answered_by_human_and_caller_not_available?.should be_true
    end
    
    it "should return true if caller session is not available" do
      @caller_session.update_attributes(on_call: true, available_for_call: true)
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      call.answered_by_human_and_caller_not_available?.should be_true
    end
    
  end
  
  describe "call did not connect" do
    
    it "should return true if busy" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "busy")
      call.call_did_not_connect?.should be_true
    end
    
    it "should return true if no answer" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "no-answer")
      call.call_did_not_connect?.should be_true
    end
    
    it "should return true if failed" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "failed")
      call.call_did_not_connect?.should be_true
    end
    
    it "should return false if completed" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "completed")
      call.call_did_not_connect?.should be_false
    end
    
    
    
  end

end