require "spec_helper"

describe WebuiCallerSession do

  describe "initial state" do

    describe "caller moves to connected" do
      before(:each) do
        @account = Factory(:account)
        @script = Factory(:script)
        @campaign =  Factory(:predictive, script: @script)
        @callers_campaign =  Factory(:predictive, script: @script)
        @caller = Factory(:caller, campaign: @callers_campaign, account: @account)
      end

      it "set state to caller connected" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(false)
        caller_session.should_receive(:is_on_call?).and_return(false)
        RedisOnHoldCaller.should_receive(:add).with(@campaign.id, caller_session.id)
        caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        caller_session.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["on_hold", @campaign.id, nil, caller_session.id])
        caller_session.start_conf!
        caller_session.state.should eq("connected")
      end

      it "shouild render correct twiml" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(false)
        caller_session.should_receive(:is_on_call?).and_return(false)
        RedisOnHoldCaller.should_receive(:add).with(@campaign.id, caller_session.id)
        caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        caller_session.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["on_hold", @campaign.id, nil, caller_session.id])
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end

    end

    describe "caller reassigned " do

      before(:each) do
        @account = Factory(:account)
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @callers_campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @callers_campaign, account: @account)
      end

      xit "set state to connected when campaign changes" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(false)
        caller_session.should_receive(:is_on_call?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)
        caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        caller_session.start_conf!
        caller_session.campaign.should eq(@caller.campaign)
        caller_session.state.should eq("connected")
      end

      xit "shouild render correct twiml" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(false)
        caller_session.should_receive(:is_on_call?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)
        caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"></Conference></Dial></Response>")
      end

    end

  end



  describe "connected state" do


    describe "paused" do

      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @call_attempt = Factory(:call_attempt, connecttime: Time.now)
      end

      it "should move to paused state if call not wrapped up" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", attempt_in_progress: @call_attempt)
        call_attempt = Factory(:call_attempt, connecttime: Time.now)
        caller_session.pause_conf!
        caller_session.state.should eq("paused")
      end

      it "when paused should render right twiml" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected",  attempt_in_progress: @call_attempt)
        call_attempt = Factory(:call_attempt, connecttime: Time.now)
        caller_session.pause_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Please enter your call results</Say><Pause length=\"600\"/></Response>")
      end

    end

    describe "connected" do

      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:predictive, script: @script)
        @caller = Factory(:caller, campaign: @campaign, account: Factory(:account))
        @call_attempt = Factory(:call_attempt)
      end


      it "should move back to connected " do
        @call_attempt.update_attributes(wrapup_time: Time.now)
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", attempt_in_progress: @call_attempt)
        caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        RedisOnHoldCaller.should_receive(:add).with(@campaign.id,caller_session.id)
        caller_session.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["on_hold", @campaign.id, nil, caller_session.id])
        caller_session.start_conf!
        caller_session.state.should eq("connected")
      end

      it "should render correct twiml if caller is ready" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", attempt_in_progress: @call_attempt)
        RedisOnHoldCaller.should_receive(:add).with(@campaign.id,caller_session.id)
        caller_session.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["on_hold", @campaign.id, nil, caller_session.id])        
        caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end
    end

    describe "stop calling" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @campaign, account: Factory(:account))
        @call_attempt = Factory(:call_attempt)
      end

      it "should end caller session if stop calling" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
        caller_session.should_receive(:end_running_call)
        caller_session.stop_calling!
        caller_session.state.should eq("stopped")
      end
    end
    
    describe "run out of phone numbers" do
      it "should move to campaign_out_of_phone_numbers state" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
        caller_session.run_ot_of_phone_numbers!
        caller_session.state.should eq("campaign_out_of_phone_numbers")
      end
      
      it "should render hangup twiml" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
        caller_session.run_ot_of_phone_numbers!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>This campaign has run out of phone numbers.</Say><Hangup/></Response>")
      end
      
      
    end

  end

  describe "paused state" do

    describe "time_period_exceeded" do

      before(:each) do
        @account = Factory(:account)
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script,:start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
        @caller = Factory(:caller, campaign: @campaign, account: @account)
      end

      it "set state to time_period_exceeded" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq("time_period_exceeded")
      end

      it "shouild render correct twiml" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 9 AM and 9 PM. Please try back during those hours.</Say><Hangup/></Response>")
      end
    end

    describe "connected" do

      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
      end

      it "set state to connected" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(false)
        caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])        
        caller_session.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["on_hold", @campaign.id, nil, caller_session.id])
        caller_session.start_conf!
        caller_session.state.should eq("connected")
      end

      it "shouild render correct twiml" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(false)
        caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        caller_session.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["on_hold", @campaign.id, nil, caller_session.id])
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end

    end

    describe "stop calling" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @campaign, account: Factory(:account))
        @call_attempt = Factory(:call_attempt)
      end

      it "should end caller session if stop calling" do
        caller_session = Factory(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused", voter_in_progress: nil)
        caller_session.should_receive(:end_running_call)
        caller_session.stop_calling!
        caller_session.state.should eq("stopped")
      end

    end


  end



end