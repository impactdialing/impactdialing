require "spec_helper"

describe PhonesOnlyCallerSession, :type => :model do

  describe "initial" do
    describe "callin_choice " do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @callers_campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @callers_campaign)
      end

      it "should render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        expect(caller_session.callin_choice).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/read_instruction_options?session_id=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
      end
    end

  end

  describe "read_choice" do

    describe "readinstruction to instructions_options  if # selected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @callers_campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @callers_campaign)
      end

      it "should render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "#", state: "read_choice")
        RedisCallerSession.set_request_params(caller_session.id, {digit: "#", question_number: 0})
        expect(caller_session.read_choice).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>After these instructions, you will be placed on hold. When someone answers the phone, the hold music will stop. You usually won't hear the person say hello, so start talking immediately. At the end of the conversation, do not hang up your phone. Instead, press star to end the call, and you will be given instructions on how to enter your call results.</Say><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/callin_choice?session_id=#{caller_session.id}</Redirect></Response>")
      end

    end

    describe "readinstruction to read_choice  if wrong option selected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @callers_campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @callers_campaign)
      end


      it "should render twiml if wrong option selected" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, digit: "x", state: "read_choice")
        RedisCallerSession.set_request_params(caller_session.id, {digit: "x", question_number: 0})
        expect(caller_session.read_choice).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/read_instruction_options?session_id=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
      end

    end

    describe "readinstruction to ready to call if * selected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @callers_campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign)
      end

      it "should render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "read_choice", digit: "*")
        RedisCallerSession.set_request_params(caller_session.id, {digit: "*", question_number: 0})
        expect(caller_session.read_choice).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/ready_to_call?session_id=#{caller_session.id}</Redirect></Response>")
      end

    end


  end

  describe "ready_to_call" do
    before do
      admin           = create(:user)
      @account        = admin.account
      @script         = create(:script, {account: @account})
      @preview        = create(:preview, script: @script, account: @account)
      @power          = create(:power, script: @script, account: @account)
    end

    shared_examples 'not fit to dial' do
      it 'not funded twiml' do
        @campaign.account.quota.update_attributes!(minutes_allowed: 0)

        caller_session = CallerSession.find @caller_session.id
        
        actual   = caller_session.ready_to_call DataCentre::Code::TWILIO
        expected = caller_session.account_has_no_funds_twiml

        expect(actual).to eq expected
      end

      it 'outside calling hours twiml' do
        @campaign.update_attributes(start_time: Time.now - 3.hours, end_time: Time.now - 2.hours)

        caller_session = CallerSession.find @caller_session.id

        actual   = caller_session.ready_to_call DataCentre::Code::TWILIO
        expected = caller_session.time_period_exceeded

        expect(actual).to eq expected
      end

      it 'account disabled' do
        @campaign.account.quota.update_attributes!(disable_calling: true)

        caller_session = CallerSession.find @caller_session.id

        actual = caller_session.ready_to_call DataCentre::Code::TWILIO
        expected = caller_session.calling_is_disabled_twiml
        p actual
        expect(actual).to eq expected
      end
    end

    describe "choose voter for preview" do
      before(:each) do
        @script           = create(:script)
        @campaign         = @preview
        @callers_campaign = @campaign
        @caller           = create(:caller, campaign: @campaign, account: @account)
        @caller_session   = create(:bare_caller_session, :phones_only, :available, {caller: @caller, campaign: @campaign})
        @voter            = create(:voter, campaign: @campaign)
      end

      it_behaves_like 'not fit to dial'

      it "should set voter in progress for session" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        expect(caller_session.voter_in_progress.id).to eq(@voter.id)
      end

      it "should render twiml for preview when voters present" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        voter = create(:voter, first_name:"first", last_name:"last")
        expect(@campaign).to receive(:next_voter_in_dial_queue).and_return(voter)
        expect(caller_session.ready_to_call(DataCentre::Code::TWILIO)).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/conference_started_phones_only_preview?session_id=#{caller_session.id}&amp;voter=#{voter.id}\" method=\"POST\" finishOnKey=\"5\"><Say>first  last. Press star to dial or pound to skip.</Say></Gather></Response>")
      end

      it "should render twiml for preview when no voters present" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        expect(@campaign).to receive(:next_voter_in_dial_queue).and_return(nil)
        expect(caller_session.ready_to_call(DataCentre::Code::TWILIO)).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say><Hangup/></Response>")
      end
    end

    describe "choose voter for power" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:power, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter, campaign: @campaign)
      end

      it "should set voter in progress" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        expect(caller_session.voter_in_progress.id).to eq(@voter.id)
      end


      it "should render twiml for power when voters present" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        voter = create(:voter, first_name:"first", last_name:"last")
        expect(@campaign).to receive(:next_voter_in_dial_queue).and_return(voter)
        expect(caller_session.ready_to_call(DataCentre::Code::TWILIO)).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>first  last.</Say><Redirect method=\"POST\">http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/conference_started_phones_only_power?session_id=#{caller_session.id}&amp;voter_id=#{voter.id}</Redirect></Response>")
      end

      it "should render twiml for power when no voters present" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        expect(@campaign).to receive(:next_voter_in_dial_queue).and_return(nil)
        expect(caller_session.ready_to_call(DataCentre::Code::TWILIO)).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say><Hangup/></Response>")
      end
    end

    describe "start conference for predictive" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:predictive, script: @script)
        @caller = create(:caller, campaign: @campaign)
      end


      it "should set on_call to true" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        expect(caller_session).to receive(:predictive?).and_return(true)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        expect(caller_session.on_call).to be_truthy
      end

      it "should set available_for_call to true" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        expect(caller_session).to receive(:predictive?).and_return(true)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        expect(caller_session.available_for_call).to be_truthy
      end

      it "should set attempt_in_progress to nil" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        expect(caller_session).to receive(:predictive?).and_return(true)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        expect(caller_session.attempt_in_progress).to be_nil
      end


      it "render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        expect(caller_session).to receive(:predictive?).and_return(true)
        expect(caller_session.ready_to_call(DataCentre::Code::TWILIO)).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/gather_response?question_number=0&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end
    end
  end

  describe "choosing_voter_to_dial" do
    before(:each) do
      @script = create(:script)
      @campaign =  create(:preview, script: @script)
      @caller = create(:caller, campaign: @campaign)
    end

    describe "skip voter if # selected" do

      it "should render correct twiml if pound selected" do
        voter = create(:voter, first_name:"first", last_name:"last")
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "#", voter_in_progress: voter)
        RedisCallerSession.set_request_params(caller_session.id, {digit: "#", question_number: 0})
        expect(voter).to receive(:skip)
        expect(caller_session.conference_started_phones_only_preview).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/ready_to_call?session_id=#{caller_session.id}</Redirect></Response>")
      end

    end

    describe "start conference for preview if * selected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter, campaign: @campaign)
      end

      it "should set attempt_in_progress to nil" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", digit: "*", voter_in_progress: @voter)
        RedisCallerSession.set_request_params(caller_session.id, {digit: "*", question_number: 0})
        expect(caller_session).to receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.id])
        caller_session.conference_started_phones_only_preview
        expect(caller_session.attempt_in_progress).to be_nil
      end


      it "render correct twiml" do
        question = create(:question, script: @script)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        RedisCallerSession.set_request_params(caller_session.id, {digit: "*", question_number: 0})
        expect(caller_session).to receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.id])
        expect(caller_session.conference_started_phones_only_preview).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/gather_response?question_number=0&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end
    end

    describe "read_to_call for preview if wrong option selected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
      end

      it "should set caller state to ready_to_call if nothing selected" do
        voter = create(:voter, first_name:"first", last_name:"last")
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_to_dial", voter_in_progress: voter)
        RedisCallerSession.set_request_params(caller_session.id, {question_number: 0})
        expect(caller_session.conference_started_phones_only_preview).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/conference_started_phones_only_preview?session_id=#{caller_session.id}&amp;voter=#{voter.id}\" method=\"POST\" finishOnKey=\"5\"><Say>first  last. Press star to dial or pound to skip.</Say></Gather></Response>")
      end

    end
  end

  describe "choosing_voter_and_dial" do
    describe "start conference for power" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:power, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter, campaign: @campaign)
      end


      it "should set attempt_in_progress to nil" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        expect(caller_session).to receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.id])
        caller_session.conference_started_phones_only_power
        expect(caller_session.attempt_in_progress).to be_nil
      end

      it "render correct twiml" do
        question = create(:question, script: @script)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        expect(caller_session).to receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.id])
        expect(caller_session.conference_started_phones_only_power).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/gather_response?question_number=0&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end
    end
  end

  describe "conference_started_phones_only" do

    describe "gather_response to read_next_question" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:power, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script, text: "How do you like Impactdialing")
      end

      it "should render correct twiml" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt, question_number: 0, script_id: @script.id)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0})
        expect(caller_session).to receive(:call_answered?).and_return(true)
        expect(RedisQuestion).to receive(:get_question_to_read).with(@script.id, caller_session.question_number).and_return({"id"=> @question.id, "question_text"=> "How do you like Impactdialing"})
        expect(RedisPossibleResponse).to receive(:possible_responses).and_return([{"id"=>@question.id, "keypad"=> 1, "value"=>"Great"}, {"id"=>@question.id, "keypad"=>2, "value"=>"Super"}])
        expect(caller_session.gather_response).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/submit_response?question_id=#{@question.id}&amp;question_number=0&amp;session_id=#{caller_session.id}\" method=\"POST\"><Say>How do you like Impactdialing</Say><Say>press 1 for Great</Say><Say>press 2 for Super</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
      end
    end
  end

  describe "conference_started_phones_only_predictive" do

    before(:each) do
      @script = create(:script)
      @campaign =  create(:predictive, script: @script)
      @caller = create(:caller, campaign: @campaign)
      @voter = create(:voter)
      @question = create(:question, script: @script, text: "How do you like Impactdialing")
    end

    describe "gather_response to read_next_question" do
      it "should render correct twiml" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt, question_number: 0, script_id: @script.id)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0})
        expect(RedisQuestion).to receive(:get_question_to_read).with(@script.id, caller_session.question_number).and_return({"id"=> @question.id, "question_text"=> "How do you like Impactdialing"})
        expect(RedisPossibleResponse).to receive(:possible_responses).and_return([{"id"=>@question.id, "keypad"=> 1, "value"=>"Great"}, {"id"=>@question.id, "keypad"=>2, "value"=>"Super"}])
        expect(caller_session).to receive(:call_answered?).and_return(true)
        expect(caller_session.gather_response).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/submit_response?question_id=#{@question.id}&amp;question_number=0&amp;session_id=#{caller_session.id}\" method=\"POST\"><Say>How do you like Impactdialing</Say><Say>press 1 for Great</Say><Say>press 2 for Super</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
      end
    end

    describe "run out of phone numbers" do
      it "should render hangup twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "conference_started_phones_only_predictive", voter_in_progress: nil)
        @campaign.caller_sessions << caller_session
        @campaign.save!
        expect(caller_session.campaign_out_of_phone_numbers).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>This campaign has run out of phone numbers.</Say><Hangup/></Response>")
      end
    end
  end


  describe "read_next_question" do

    describe "disconnected" do

      before(:each) do
        @script = create(:script)
        @campaign =  create(:power, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script)
      end


      it "render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        expect(caller_session).to receive(:disconnected?).and_return(true)
        expect(caller_session.submit_response).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end

    end

     describe "wrapup_call" do

      before(:each) do
        @script = create(:script)
        @campaign =  create(:power, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script)
      end

      it "render correct twiml" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        expect(caller_session).to receive(:disconnected?).and_return(false)
        expect(caller_session).to receive(:skip_all_questions?).and_return(true)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        expect(caller_session.submit_response).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/next_call?session_id=#{caller_session.id}</Redirect></Response>")
      end

      end

    describe "voter response" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:power, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script)
      end


      it "should persist the answer " do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", question_id: @question.id, attempt_in_progress: call_attempt, voter_in_progress: @voter, digit: 1)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        expect(caller_session).to receive(:disconnected?).and_return(false)
        expect(RedisPhonesOnlyAnswer).to receive(:push_to_list).with(@voter.id, caller_session.id, 1, 1)
        caller_session.submit_response
      end

      it "should render correct twiml " do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt, question_number: 0)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        expect(caller_session).to receive(:disconnected?).and_return(false)
        expect(caller_session.submit_response).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/next_question?question_number=1&amp;session_id=#{caller_session.id}</Redirect></Response>")
      end

    end
  end

  describe "voter_response" do
    before(:each) do
      @script = create(:script)
      @campaign =  create(:power, script: @script)
      @caller = create(:caller, campaign: @campaign)
      @voter = create(:voter)
       @question = create(:question, script: @script, text: "How do you like Impactdialing")
    end

    describe "more_questions_to_be_answered" do

      it "should move to read_next_question state" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "voter_response", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt, script_id: @script.id)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        expect(RedisQuestion).to receive(:get_question_to_read).with(@script.id, caller_session.redis_question_number).and_return({"id"=> @question.id, "question_text"=> "How do you like Impactdialing"})
        expect(RedisPossibleResponse).to receive(:possible_responses).and_return([{"id"=>@question.id, "keypad"=> 1, "value"=>"Great"}, {"id"=>@question.id, "keypad"=>2, "value"=>"Super"}])
        expect(caller_session).to receive(:more_questions_to_be_answered?).and_return(true)
        expect(caller_session.next_question).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/submit_response?question_id=#{@question.id}&amp;question_number=0&amp;session_id=#{caller_session.id}\" method=\"POST\"><Say>How do you like Impactdialing</Say><Say>press 1 for Great</Say><Say>press 2 for Super</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
      end

    end

    describe "no_more_questions_to_be_answered" do
      it "should move to read_next_question state" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "voter_response", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        expect(caller_session).to receive(:more_questions_to_be_answered?).and_return(false)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        expect(RedisStatus).to receive(:set_state_changed_time).with(@campaign.id, "On hold",caller_session.id)
        expect(caller_session.next_question).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/next_call?session_id=#{caller_session.id}</Redirect></Response>")
      end

    end
  end

end

# ## Schema Information
#
# Table name: `caller_sessions`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`caller_id`**             | `integer`          |
# **`campaign_id`**           | `integer`          |
# **`endtime`**               | `datetime`         |
# **`starttime`**             | `datetime`         |
# **`sid`**                   | `string(255)`      |
# **`available_for_call`**    | `boolean`          | `default(FALSE)`
# **`voter_in_progress_id`**  | `integer`          |
# **`created_at`**            | `datetime`         |
# **`updated_at`**            | `datetime`         |
# **`on_call`**               | `boolean`          | `default(FALSE)`
# **`caller_number`**         | `string(255)`      |
# **`tCallSegmentSid`**       | `string(255)`      |
# **`tAccountSid`**           | `string(255)`      |
# **`tCalled`**               | `string(255)`      |
# **`tCaller`**               | `string(255)`      |
# **`tPhoneNumberSid`**       | `string(255)`      |
# **`tStatus`**               | `string(255)`      |
# **`tDuration`**             | `integer`          |
# **`tFlags`**                | `integer`          |
# **`tStartTime`**            | `datetime`         |
# **`tEndTime`**              | `datetime`         |
# **`tPrice`**                | `float`            |
# **`attempt_in_progress`**   | `integer`          |
# **`session_key`**           | `string(255)`      |
# **`state`**                 | `string(255)`      |
# **`type`**                  | `string(255)`      |
# **`digit`**                 | `string(255)`      |
# **`debited`**               | `boolean`          | `default(FALSE)`
# **`question_id`**           | `integer`          |
# **`caller_type`**           | `string(255)`      |
# **`question_number`**       | `integer`          |
# **`script_id`**             | `integer`          |
# **`reassign_campaign`**     | `string(255)`      | `default("no")`
#
# ### Indexes
#
# * `index_caller_sessions_debit`:
#     * **`debited`**
#     * **`caller_type`**
#     * **`tStartTime`**
#     * **`tEndTime`**
#     * **`tDuration`**
# * `index_caller_sessions_on_caller_id`:
#     * **`caller_id`**
# * `index_caller_sessions_on_campaign_id`:
#     * **`campaign_id`**
# * `index_caller_sessions_on_sid`:
#     * **`sid`**
# * `index_callers_on_call_group_by_campaign`:
#     * **`campaign_id`**
#     * **`on_call`**
# * `index_state_caller_sessions`:
#     * **`state`**
#
