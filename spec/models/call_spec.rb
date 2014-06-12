require "spec_helper"

describe Call do

  describe "initial" do

    describe "incoming call answered by human" do

      before(:each) do
        @caller = create(:caller)
        @script = create(:script)
        @campaign =  create(:predictive, script: @script)
        @voter  = create(:voter, campaign: @campaign)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign)
        @caller_session = create(:webui_caller_session, caller: @caller, campaign: @campaign, voter_in_progress: @voter, attempt_in_progress: @call_attempt, on_call: true, available_for_call: false, state: "connected", sid: "123456")
        @call_attempt.caller_session = @caller_session
        @call_attempt.save!
      end

      it "should start a conference in connected state" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
        RedisCall.set_request_params(call.id, call.attributes)
        call.should_receive(:enqueue_call_flow)
        call.incoming_call.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"http://#{Settings.twilio_callback_host}/calls/#{call.id}/disconnected\" record=\"false\"><Conference waitUrl=\"hold_music\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\"/></Dial></Response>")
      end

      it "should start a conference in connected state with callsid if call not from twilio" do
        pending "review & removal"
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
        RedisCall.set_request_params(call.id, call.attributes)
        RedisCallerSession.set_datacentre(@caller_session.id, DataCentre::Code::ORL)
        call.should_receive(:enqueue_call_flow)
        call.incoming_call.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"http://voxeo-prodaws.impactdialing.com/calls/#{call.id}/disconnected\" record=\"false\"><Conference waitUrl=\"hold_music\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\"/><CallerSid>123456</CallerSid></Dial></Response>")
      end


    end


    describe "incoming call answered by human that need to be abandoned" do
        before(:each) do
          @caller = create(:caller)
          @script = create(:script)
          @campaign =  create(:predictive, script: @script)
          @voter  = create(:voter, campaign: @campaign, caller_session: @caller_session)
          @caller_session = create(:webui_caller_session, caller: @caller, campaign: @campaign, voter_in_progress: @voter, attempt_in_progress: @call_attempt)
          @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller: @caller)
        end

        it "should return hangup twiml for abandoned users" do
          call = create(:call, answered_by: "human", call_attempt: @call_attempt, call_status: 'in-progress')
          RedisCall.set_request_params(call.id, call.attributes)
          RedisCallFlow.should_receive(:push_to_abandoned_call_list).with(call.id);
          @call_attempt.should_receive(:redirect_caller)
          call.incoming_call.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
        end

      end

    describe "incoming call answered by machine" do

        before(:each) do
          @caller = create(:caller)
          @script = create(:script)
          @campaign =  create(:preview, script: @script, use_recordings: false)
          @voter = create(:voter, campaign: @campaign)
          @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller: @caller)
        end

        it "should render the user recording and hangup if user recording present" do
          recording = create(:recording)
          @campaign.update_attributes(recording_id: recording.id, use_recordings: true)
          call = create(:call, answered_by: "machine", call_attempt: @call_attempt)
          RedisCall.set_request_params(call.id, call.attributes)
          RedisCallFlow.should_receive(:push_to_processing_by_machine_call_hash).with(call.id);
          @call_attempt.should_receive(:redirect_caller)
          call.incoming_call.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Play>http://s3.amazonaws.com/impactdialing_production/test/uploads/unknown/#{recording.id}.mp3</Play><Hangup/></Response>")
        end

        it "should render  and hangup if user recording is not present" do
          call = create(:call, answered_by: "machine", call_attempt: @call_attempt)
          RedisCall.set_request_params(call.id, call.attributes)
          RedisCallFlow.should_receive(:push_to_processing_by_machine_call_hash).with(call.id);
          @call_attempt.should_receive(:redirect_caller)
          call.incoming_call.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
        end

      end

  end

  describe "connected" do

   describe "hangup "  do
     before(:each) do
      @caller = create(:caller)
       @script = create(:script)
       @campaign =  create(:campaign, script: @script)
       @voter = create(:voter, campaign: @campaign)
       @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, sid: "abc", caller: @caller)
     end

     it "should render nothing" do
       call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
       RedisCall.set_request_params(call.id, call.attributes)
       @call_attempt.should_receive(:enqueue_call_flow).with(EndRunningCallJob, [@call_attempt.sid])
       call.hungup
     end
  end

  describe "disconnect"  do
    before(:each) do
      @script = create(:script)
      @campaign =  create(:campaign, script: @script)
      @caller = create(:caller)
      @caller_session = create(:caller_session, caller: @caller)
      @voter = create(:voter, campaign: @campaign, caller_session: @caller_session)
      @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
    end

    it "should hangup twiml" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'connected')
      RedisCall.set_request_params(call.id, call.attributes)
      RedisCallFlow.should_receive(:push_to_disconnected_call_list).with(call.id, call.recording_duration, call.recording_url, @caller.id)
      @call_attempt.should_receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])
      call.disconnected.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end
  end
end

  describe "hungup" do

    describe "disconnect call" do
      before(:each) do
       @script = create(:script)
       @campaign =  create(:campaign, script: @script)
       @caller = create(:caller)
       @caller_session = create(:caller_session, caller: @caller)
       @voter = create(:voter, campaign: @campaign, caller_session: @caller_session)
       @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
      end


      it "should hangup twiml" do
       call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'hungup')
       RedisCall.set_request_params(call.id, call.attributes)
       RedisCallFlow.should_receive(:push_to_disconnected_call_list).with(call.id, call.recording_duration, call.recording_url, @caller.id)
       RedisStatus.should_receive(:set_state_changed_time).with(@campaign.id, "Wrap up", @caller_session.id)
       @call_attempt.should_receive(:enqueue_call_flow).with(CallerPusherJob, [@caller_session.id, "publish_voter_disconnected"])
       call.disconnected.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end
    end

  end


  describe "call_answered_by_lead" do
    describe "submit_result" do

      before(:each) do
        @caller = create(:caller)
        @script = create(:script)
        @campaign =  create(:campaign, script: @script)
        @voter = create(:voter, campaign: @campaign)
        @caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
      end
      it "should warp up and continue" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected')
        RedisCall.set_request_params(call.id, call.attributes)
        RedisCallFlow.should_receive(:push_to_wrapped_up_call_list).with(@call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT);
        @call_attempt.should_receive(:redirect_caller)
        RedisStatus.should_receive(:set_state_changed_time).with(@campaign.id, "On hold", @caller_session.id)
        call.wrapup_and_continue
      end

    end

    describe "submit_result_and_stop" do
      before(:each) do
        @caller = create(:caller)
        @script = create(:script)
        @campaign =  create(:campaign, script: @script)
        @voter = create(:voter, campaign: @campaign)
        @caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session, caller: @caller)
      end

      it "should wrapup and stop" do
        call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected')
        RedisCall.set_request_params(call.id, call.attributes)
        RedisCallFlow.should_receive(:push_to_wrapped_up_call_list).with(@call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT);
        @call_attempt.should_receive(:end_caller_session)
        call.wrapup_and_stop
      end

    end
  end

  describe "state machine methods" do
    it "should return answered by machine" do
      call = create(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'disconnected')
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_machine?.should be_true
    end

    it "should return answered by human" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'disconnected')
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_human?.should be_true
    end

    describe "answered_by_human_and_caller_available?"

    before(:each) do
      @script = create(:script)
      @campaign =  create(:campaign, script: @script)
      @voter = create(:voter, campaign: @campaign)
      @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign, caller_session: @caller_session)
      @caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, attempt_in_progress: @call_attempt, state: "connected")
    end

    it "should return answered_by_human_and_caller_available?" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_human_and_caller_available?.should be_true
    end

    it "should return false if not answered by human" do
      call = create(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_human_and_caller_available?.should be_false
    end

    it "should return false if call status is not in progress" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "completed")
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_human_and_caller_available?.should be_false
    end

    it "should return false if caller session is nil" do
      @caller_session.update_attributes(attempt_in_progress: nil)
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_human_and_caller_available?.should be_false
    end

    it "should return false if caller session is not available" do
      @caller_session.update_attributes(on_call: false)
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_human_and_caller_available?.should be_false
    end

    it "should return true if caller session is nil" do
      @caller_session.update_attributes(attempt_in_progress: nil)
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_human_and_caller_not_available?.should be_true
    end

    it "should return true if caller session is not available" do
      @caller_session.update_attributes(on_call: true, available_for_call: true)
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "in-progress")
      RedisCall.set_request_params(call.id, call.attributes)
      call.answered_by_human_and_caller_not_available?.should be_true
    end

  end

  describe "call did not connect" do

    it "should return true if busy" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "busy")
      RedisCall.set_request_params(call.id, call.attributes)
      call.call_did_not_connect?.should be_true
    end

    it "should return true if no answer" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "no-answer")
      RedisCall.set_request_params(call.id, call.attributes)
      call.call_did_not_connect?.should be_true
    end

    it "should return true if failed" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "failed")
      RedisCall.set_request_params(call.id, call.attributes)
      call.call_did_not_connect?.should be_true
    end

    it "should return false if completed" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "completed")
      RedisCall.set_request_params(call.id, call.attributes)
      call.call_did_not_connect?.should be_false
    end



  end

  describe "call_ended" do

    before(:each) do
      @caller = create(:caller)
      @script = create(:script)
      @campaign =  create(:predictive, script: @script)
      @voter  = create(:voter, campaign: @campaign)
      @call_attempt = create(:call_attempt, voter: @voter, campaign: @campaign)
      @caller_session = create(:webui_caller_session, caller: @caller, campaign: @campaign, voter_in_progress: @voter, attempt_in_progress: @call_attempt, on_call: true, available_for_call: false, state: "connected", sid: "123456")
      @call_attempt.caller_session = @caller_session
      @call_attempt.save!
    end

    it "should push to not connected call list if call did not connect" do
      call = create(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "busy")
      RedisCall.set_request_params(call.id, call.attributes)
      RedisCallFlow.should_receive(:push_to_not_answered_call_list).with(call.id, "busy")
      call.call_ended("Preview")
    end

    it "should push to end by machine call list if answered by machine" do
      call = create(:call, answered_by: "machine", call_attempt: @call_attempt, state: 'initial', call_status: "busy")
      RedisCall.set_request_params(call.id, call.attributes)
      RedisCallFlow.should_receive(:push_to_end_by_machine_call_list).with(call.id)
      call.call_ended("Preview").should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end

  end

end
