require "spec_helper"

describe PhonesOnlyCallerSession do

  describe "initial" do
    describe "callin_choice " do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @callers_campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @callers_campaign)
      end


      it "should set caller state to read choice" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.callin_choice!
        caller_session.state.should eq('read_choice')
      end

      it "should render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.callin_choice!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=read_instruction_options&amp;session=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
      end
    end

  end

  describe "read_choice" do

    describe "readinstruction to instructions_options  if # selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @callers_campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @callers_campaign)
      end

      it "should set caller state to instructions_options" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "#", state: "read_choice")
        caller_session.read_instruction_options!
        caller_session.state.should eq('instructions_options')
      end

      it "should render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "#", state: "read_choice")
        caller_session.read_instruction_options!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>After these instructions, you will be placed on hold. When someone answers the phone, the hold music will stop. You usually won't hear the person say hello, so start talking immediately. At the end of the conversation, do not hang up your phone. Instead, press star to end the call, and you will be given instructions on how to enter your call results.</Say><Redirect>https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=callin_choice&amp;session=#{caller_session.id}</Redirect></Response>")
      end

    end

    describe "readinstruction to read_choice  if wrong option selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @callers_campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @callers_campaign)
      end

      it "should go back to read_choice if wrong option selected" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "x", state: "read_choice")
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.read_instruction_options!
        caller_session.state.should eq('read_choice')
      end

      it "should render twiml if wrong option selected" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "x", state: "read_choice")
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.read_instruction_options!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=read_instruction_options&amp;session=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
      end

      it "should set caller state to read choice" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "instructions_options")
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.callin_choice!
        caller_session.state.should eq('read_choice')
      end
    end

    describe "readinstruction to ready to call if * selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @callers_campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
      end

      it "should set caller state ready to dial" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.read_instruction_options!
        caller_session.state.should eq('ready_to_call')
      end

      it "should render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.read_instruction_options!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=start_conf&amp;session=#{caller_session.id}</Redirect></Response>")
      end

    end


  end

  describe "ready_to_call" do


    describe "time period exceeded" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script,:start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
        @callers_campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @callers_campaign)
      end

      it "should set caller state to time_period_exceeded" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq('time_period_exceeded')
      end

      it "should render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 9 AM and 9 PM. Please try back during those hours.</Say><Hangup/></Response>")
      end

    end

    describe "caller reassigned to campaign" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
      end

      it "should set caller state to reassigned to campaign" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq('reassigned_campaign')
      end

      it "should render twiml for reassigned campaign when voters present" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You have been re-assigned to a campaign.</Say><Redirect>https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?Digits=%2A&amp;event=callin_choice&amp;session=#{caller_session.id}</Redirect></Response>")
      end

    end

    describe "choose voter for preview" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @callers_campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter, campaign: @campaign)
      end

      it "should set caller state to choosing_voter_to_dial" do
        call_attempt = Factory(:call_attempt)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)
        caller_session.start_conf!
        caller_session.state.should eq('choosing_voter_to_dial')
      end

      it "should set voter in progress for session" do
        call_attempt = Factory(:call_attempt)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)
        caller_session.start_conf!
        caller_session.voter_in_progress.should eq(@voter)
      end

      it "should render twiml for preview when voters present" do
        call_attempt = Factory(:call_attempt)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        voter = Factory(:voter, FirstName:"first", LastName:"last")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(voter)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=start_conf&amp;session=#{caller_session.id}&amp;voter=#{voter.id}\" method=\"POST\" finishOnKey=\"5\"><Say>first  last. Press star to dial or pound to skip.</Say></Gather></Response>")
      end

      it "should render twiml for preview when no voters present" do
        call_attempt = Factory(:call_attempt)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(false)
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(nil)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say><Hangup/></Response>")
      end
    end

    describe "choose voter for power" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter, campaign: @campaign)
      end

      it "should set caller state to choosing_voter_and_dial" do
        call_attempt = Factory(:call_attempt)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.start_conf!
        caller_session.state.should eq('choosing_voter_and_dial')
      end

      it "should set voter in progress" do
        call_attempt = Factory(:call_attempt)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.start_conf!
        caller_session.voter_in_progress.should eq(@voter)
      end


      it "should render twiml for power when voters present" do
        call_attempt = Factory(:call_attempt)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        voter = Factory(:voter, FirstName:"first", LastName:"last")
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(voter)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>first  last.</Say><Redirect method=\"POST\">https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=start_conf&amp;session_id=#{caller_session.id}&amp;voter_id=#{voter.id}</Redirect></Response>")
      end

      it "should render twiml for power when no voters present" do
        call_attempt = Factory(:call_attempt)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(nil)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say><Hangup/></Response>")
      end
    end

    describe "start conference for predictive" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:predictive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
      end

      it "should set caller state to conference_started_phones_only" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq('conference_started_phones_only_predictive')
      end

      it "should set on_call to true" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.start_conf!
        caller_session.on_call.should be_true
      end

      it "should set available_for_call to true" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.start_conf!
        caller_session.available_for_call.should be_true
      end

      it "should set attempt_in_progress to nil" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.start_conf!
        caller_session.attempt_in_progress.should be_nil
      end


      it "render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=gather_response&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"></Conference></Dial></Response>")
      end
    end
  end

  describe "choosing_voter_to_dial" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:preview, script: @script)
      @caller = Factory(:caller, campaign: @campaign)
    end

    describe "skip voter if # selected" do
      it "should set caller state to skipped voter if pound selected" do
        voter = Factory(:voter, FirstName:"first", LastName:"last")
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "#", voter_in_progress: voter)
        voter.should_receive(:skip)
        caller_session.start_conf!
        caller_session.state.should eq('skip_voter')
      end

      it "should render correct twiml if pound selected" do
        voter = Factory(:voter, FirstName:"first", LastName:"last")
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "#", voter_in_progress: voter)
        voter.should_receive(:skip)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=skipped_voter&amp;session=#{caller_session.id}</Redirect></Response>")
      end

    end

    describe "start conference for preview if * selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter)
      end


      it "should set caller state to conference_started_phones_only" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        caller_session.start_conf!
        caller_session.state.should eq('conference_started_phones_only')
      end

      it "should set on_call to true" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        caller_session.start_conf!
        caller_session.on_call.should be_true
      end

      it "should set available_for_call to true" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        caller_session.start_conf!
        caller_session.available_for_call.should be_true
      end

      it "should set attempt_in_progress to nil" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        caller_session.start_conf!
        caller_session.attempt_in_progress.should be_nil
      end


      it "render correct twiml" do
        question = Factory(:question, script: @script)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        @voter.should_receive(:question_not_answered).and_return(question)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=gather_response&amp;question=#{question.id}&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"></Conference></Dial></Response>")
      end
    end

    describe "read_to_call for preview if wrong option selected" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:preview, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
      end

      it "should set caller state to ready_to_call" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "+")
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.start_conf!
        caller_session.state.should eq('ready_to_call')
      end

      it "should set caller state to ready_to_call if nothing selected" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial")
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_conference_started")
        caller_session.start_conf!
        caller_session.state.should eq('ready_to_call')
      end

    end
  end

  describe "choosing_voter_and_dial" do
    describe "start conference for power" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter)
      end

      it "should set caller state to conference_started_phones_only" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        caller_session.start_conf!
        caller_session.state.should eq('conference_started_phones_only')
      end

      it "should set on_call to true" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        caller_session.start_conf!
        caller_session.on_call.should be_true
      end

      it "should set available_for_call to true" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        caller_session.start_conf!
        caller_session.available_for_call.should be_true
      end

      it "should set attempt_in_progress to nil" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        caller_session.start_conf!
        caller_session.attempt_in_progress.should be_nil
      end

      it "render correct twiml" do
        question = Factory(:question, script: @script)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, @voter.id)
        @voter.should_receive(:question_not_answered).and_return(question)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=gather_response&amp;question=#{question.id}&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"></Conference></Dial></Response>")
      end
    end
  end

  describe "conference_started_phones_only" do

    describe "gather_response to read_next_question" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter)
        @question = Factory(:question, script: @script, text: "How do you like Impactdialing")
      end

      it "should move to voter_response state" do
        call_attempt = Factory(:call_attempt, voter: @voter)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:call_answered?).and_return(true)
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_gathering_response")
        caller_session.gather_response!
        caller_session.state.should eq('read_next_question')
      end

      it "should render correct twiml" do
        call_attempt = Factory(:call_attempt, voter: @voter)
        possible_response_1 = Factory(:possible_response, question: @question, keypad: 1, value: "Great")
        possible_response_2 = Factory(:possible_response, question: @question, keypad: 2, value: "Super")
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:unanswered_question).exactly(3).and_return(@question)
        caller_session.should_receive(:call_answered?).and_return(true)
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_gathering_response")
        caller_session.gather_response!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=submit_response&amp;question_id=#{@question.id}&amp;session_id=#{caller_session.id}\" method=\"POST\"><Say>How do you like Impactdialing</Say><Say>press 1 for Great</Say><Say>press 2 for Super</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
      end
    end
  end

  describe "conference_started_phones_only_predictive" do

    describe "gather_response to read_next_question" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:predictive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter)
        @question = Factory(:question, script: @script, text: "How do you like Impactdialing")
      end

      it "should move to voter_response state" do
        call_attempt = Factory(:call_attempt, voter: @voter)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:call_answered?).and_return(true)
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_gathering_response")
        caller_session.gather_response!
        caller_session.state.should eq('read_next_question')
      end

      it "should render correct twiml" do
        call_attempt = Factory(:call_attempt, voter: @voter)
        possible_response_1 = Factory(:possible_response, question: @question, keypad: 1, value: "Great")
        possible_response_2 = Factory(:possible_response, question: @question, keypad: 2, value: "Super")
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:unanswered_question).exactly(3).and_return(@question)
        caller_session.should_receive(:call_answered?).and_return(true)
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_gathering_response")
        caller_session.gather_response!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=submit_response&amp;question_id=#{@question.id}&amp;session_id=#{caller_session.id}\" method=\"POST\"><Say>How do you like Impactdialing</Say><Say>press 1 for Great</Say><Say>press 2 for Super</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
      end
    end
  end


  describe "read_next_question" do

    describe "disconnected" do

      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter)
        @question = Factory(:question, script: @script)
      end


      it "move to disconnect state if caller disconnected" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id)
        caller_session.should_receive(:disconnected?).and_return(true)
        caller_session.submit_response!
        caller_session.state.should eq('disconnected')
      end

      it "render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id)
        caller_session.should_receive(:disconnected?).and_return(true)
        caller_session.submit_response!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end

    end

     describe "wrapup_call" do

      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter)
        @question = Factory(:question, script: @script)
      end


      it "move to wrapup state if caller has skipped all questions" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id)
        caller_session.should_receive(:disconnected?).and_return(false)
        caller_session.should_receive(:skip_all_questions?).and_return(true)
        caller_session.submit_response!
        caller_session.state.should eq('wrapup_call')
      end

      it "render correct twiml" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id)
        caller_session.should_receive(:disconnected?).and_return(false)
        caller_session.should_receive(:skip_all_questions?).and_return(true)
        caller_session.submit_response!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=next_call&amp;session=#{caller_session.id}</Redirect></Response>")
      end

      end

    describe "voter response" do
      before(:each) do
        @script = Factory(:script)
        @campaign =  Factory(:progressive, script: @script)
        @caller = Factory(:caller, campaign: @campaign)
        @voter = Factory(:voter)
        @question = Factory(:question, script: @script)
      end

      it "move to voter_response state " do
        call_attempt = Factory(:call_attempt, voter: @voter)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:disconnected?).and_return(false)
        caller_session.submit_response!
        caller_session.state.should eq('voter_response')
      end

      it "should persist the answer " do
        call_attempt = Factory(:call_attempt, voter: @voter)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:disconnected?).and_return(false)
        Question.should_receive(:find_by_id).and_return(@question)
        caller_session.attempt_in_progress.voter.should_receive(:answer)
        caller_session.submit_response!
      end

      it "should render correct twiml " do
        call_attempt = Factory(:call_attempt, voter: @voter)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:disconnected?).and_return(false)
        caller_session.submit_response!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>https://#{Settings.host}:#{Settings.port}/caller/#{@caller.id}/flow?event=next_question&amp;session=#{caller_session.id}</Redirect></Response>")
      end

    end
  end

  describe "voter_response" do
    before(:each) do
      @script = Factory(:script)
      @campaign =  Factory(:progressive, script: @script)
      @caller = Factory(:caller, campaign: @campaign)
      @voter = Factory(:voter)
      @question = Factory(:question, script: @script)
    end

    describe "more_questions_to_be_answered" do
      it "should move to read_next_question state" do
        call_attempt = Factory(:call_attempt, voter: @voter)
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "voter_response", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:more_questions_to_be_answered?).and_return(true)
        Resque.should_receive(:enqueue).with(ModeratorCallerJob, caller_session.id, "publish_moderator_gathering_response")        
        caller_session.next_question!
        caller_session.state.should eq('read_next_question')
      end

    end

    describe "no_more_questions_to_be_answered" do
      it "should move to read_next_question state" do
        caller_session = Factory(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "voter_response", voter_in_progress: @voter, question_id: @question.id)
        caller_session.should_receive(:more_questions_to_be_answered?).and_return(false)
        caller_session.next_question!
        caller_session.state.should eq('wrapup_call')
      end

    end





  end



















end
