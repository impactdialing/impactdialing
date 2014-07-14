require "spec_helper"

describe WebuiCallerSession, :type => :model do

  describe "initial state" do

    describe "caller moves to connected" do
      before(:each) do
        @account = create(:account)
        @script = create(:script)
        @campaign =  create(:predictive, script: @script)
        @callers_campaign =  create(:predictive, script: @script)
        @caller = create(:caller, campaign: @callers_campaign, account: @account)
      end


      it "shouild render correct twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(false)
        expect(RedisOnHoldCaller).to receive(:add).with(@campaign.id, caller_session.id, DataCentre::Code::TWILIO)
        expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        expect(caller_session.start_conf).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/pause?session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end

    end

    describe "caller reassigned " do

      before(:each) do
        @account = create(:account)
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @callers_campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @callers_campaign, account: @account)
      end

      xit "set publish correct event" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(false)
        expect(caller_session).to receive(:is_on_call?).and_return(false)
        expect(caller_session).to receive(:caller_reassigned_to_another_campaign?).and_return(true)
        expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        caller_session.start_conf!
        expect(caller_session.campaign).to eq(@caller.campaign)
        expect(caller_session.state).to eq("connected")
      end

      xit "shouild render correct twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(false)
        expect(caller_session).to receive(:is_on_call?).and_return(false)
        expect(caller_session).to receive(:caller_reassigned_to_another_campaign?).and_return(true)
        expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        caller_session.start_conf!
        expect(caller_session.render).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/flow?event=pause_conf&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"></Conference></Dial></Response>")
      end

    end

  end



  describe "connected state" do


    describe "paused" do

      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @call_attempt = create(:call_attempt, connecttime: Time.now)
      end


      it "when paused should render right twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected",  attempt_in_progress: @call_attempt)
        call_attempt = create(:call_attempt, connecttime: Time.now)
        expect(caller_session.pause).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Please enter your call results</Say><Pause length=\"600\"/></Response>")
      end

    end

    describe "connected" do

      before(:each) do
        @script = create(:script)
        @campaign =  create(:predictive, script: @script)
        @caller = create(:caller, campaign: @campaign, account: create(:account))
        @call_attempt = create(:call_attempt)
      end

      it "should render correct twiml if caller is ready" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", attempt_in_progress: @call_attempt)
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(false)

        expect(RedisOnHoldCaller).to receive(:add).with(@campaign.id,caller_session.id, DataCentre::Code::TWILIO)
        expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        expect(caller_session.start_conf).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/pause?session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end
    end

    describe "stop calling" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign, account: create(:account))
        @call_attempt = create(:call_attempt)
      end

      it "should end caller session if stop calling" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
        expect(caller_session).to receive(:end_running_call)
        caller_session.stop_calling
      end
    end

    describe "run out of phone numbers" do

      it "should render hangup twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
        expect(caller_session.campaign_out_of_phone_numbers).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>This campaign has run out of phone numbers.</Say><Hangup/></Response>")
      end


    end

  end

  describe "paused state" do

    describe "time_period_exceeded" do

      before(:each) do
        @account = create(:account)
        @script = create(:script)
        @campaign =  create(:preview, script: @script,:start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
        @caller = create(:caller, campaign: @campaign, account: @account)
      end


      it "shouild render correct twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused")
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(true)
        expect(caller_session.start_conf).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 9 AM and 9 PM. Please try back during those hours.</Say><Hangup/></Response>")
      end
    end

    describe "connected" do

      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign)
      end


      it "shouild render correct twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused")
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(false)
        expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])
        expect(caller_session.start_conf).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/pause?session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end

    end



  end



end