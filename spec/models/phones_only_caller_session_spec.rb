require "spec_helper"

describe PhonesOnlyCallerSession do

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
        caller_session.callin_choice.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/read_instruction_options?session_id=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
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
        caller_session.read_choice.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>After these instructions, you will be placed on hold. When someone answers the phone, the hold music will stop. You usually won't hear the person say hello, so start talking immediately. At the end of the conversation, do not hang up your phone. Instead, press star to end the call, and you will be given instructions on how to enter your call results.</Say><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/callin_choice?session_id=#{caller_session.id}</Redirect></Response>")
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
        caller_session.read_choice.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/read_instruction_options?session_id=#{caller_session.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
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
        caller_session.read_choice.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/ready_to_call?session_id=#{caller_session.id}</Redirect></Response>")
      end

    end


  end

  describe "ready_to_call" do

    describe "caller reassigned to campaign" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:progressive, script: @script)
        @caller = create(:caller, campaign: @campaign)
      end


      xit "should render twiml for reassigned campaign when voters present" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:caller_reassigned_to_another_campaign?).and_return(true)        
        caller_session.ready_to_call.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You have been re-assigned to a campaign.</Say><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/flow?Digits=%2A&amp;event=callin_choice&amp;session_id=#{caller_session.id}</Redirect></Response>")
      end

    end

    describe "choose voter for preview" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @callers_campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter, campaign: @campaign)
      end


      it "should set voter in progress for session" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        caller_session.voter_in_progress.id.should eq(@voter.id)
      end

      it "should render twiml for preview when voters present" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        voter = create(:voter, first_name:"first", last_name:"last")
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(voter)
        caller_session.ready_to_call(DataCentre::Code::TWILIO).should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/conference_started_phones_only_preview?session_id=#{caller_session.id}&amp;voter=#{voter.id}\" method=\"POST\" finishOnKey=\"5\"><Say>first  last. Press star to dial or pound to skip.</Say></Gather></Response>")
      end

      it "should render twiml for preview when no voters present" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(nil)
        caller_session.ready_to_call(DataCentre::Code::TWILIO).should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say><Hangup/></Response>")
      end
    end

    describe "choose voter for power" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:progressive, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter, campaign: @campaign)
      end

     
      it "should set voter in progress" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        caller_session.voter_in_progress.id.should eq(@voter.id)
      end


      it "should render twiml for power when voters present" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        voter = create(:voter, first_name:"first", last_name:"last")
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(voter)
        caller_session.ready_to_call(DataCentre::Code::TWILIO).should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>first  last.</Say><Redirect method=\"POST\">http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/conference_started_phones_only_power?session_id=#{caller_session.id}&amp;voter_id=#{voter.id}</Redirect></Response>")
      end

      it "should render twiml for power when no voters present" do
        call_attempt = create(:call_attempt)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call", attempt_in_progress: call_attempt)
        @campaign.should_receive(:next_voter_in_dial_queue).and_return(nil)
        caller_session.ready_to_call(DataCentre::Code::TWILIO).should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say><Hangup/></Response>")
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
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        caller_session.on_call.should be_true
      end

      it "should set available_for_call to true" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        caller_session.available_for_call.should be_true
      end

      it "should set attempt_in_progress to nil" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.ready_to_call(DataCentre::Code::TWILIO)
        caller_session.attempt_in_progress.should be_nil
      end


      it "render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "ready_to_call")
        caller_session.should_receive(:predictive?).and_return(true)
        caller_session.ready_to_call(DataCentre::Code::TWILIO).should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/gather_response?question_number=0&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
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
        voter.should_receive(:skip)
        caller_session.conference_started_phones_only_preview.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/ready_to_call?session_id=#{caller_session.id}</Redirect></Response>")
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
        caller_session.should_receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.id])
        caller_session.conference_started_phones_only_preview
        caller_session.attempt_in_progress.should be_nil
      end


      it "render correct twiml" do
        question = create(:question, script: @script)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        RedisCallerSession.set_request_params(caller_session.id, {digit: "*", question_number: 0})
        caller_session.should_receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.id])
        caller_session.conference_started_phones_only_preview.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/gather_response?question_number=0&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
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
        caller_session.conference_started_phones_only_preview.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/conference_started_phones_only_preview?session_id=#{caller_session.id}&amp;voter=#{voter.id}\" method=\"POST\" finishOnKey=\"5\"><Say>first  last. Press star to dial or pound to skip.</Say></Gather></Response>")
      end

    end
  end

  describe "choosing_voter_and_dial" do
    describe "start conference for power" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:progressive, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter, campaign: @campaign)
      end


      it "should set attempt_in_progress to nil" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        caller_session.should_receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.id])
        caller_session.conference_started_phones_only_power
        caller_session.attempt_in_progress.should be_nil
      end

      it "render correct twiml" do
        question = create(:question, script: @script)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "choosing_voter_and_dial", digit: "*", voter_in_progress: @voter)
        caller_session.should_receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, @voter.id])
        caller_session.conference_started_phones_only_power.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/gather_response?question_number=0&amp;session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
      end
    end
  end

  describe "conference_started_phones_only" do

    describe "gather_response to read_next_question" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:progressive, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script, text: "How do you like Impactdialing")
      end

      it "should render correct twiml" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt, question_number: 0, script_id: @script.id)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0})
        caller_session.should_receive(:call_answered?).and_return(true)
        RedisQuestion.should_receive(:get_question_to_read).with(@script.id, caller_session.question_number).and_return({"id"=> @question.id, "question_text"=> "How do you like Impactdialing"})
        RedisPossibleResponse.should_receive(:possible_responses).and_return([{"id"=>@question.id, "keypad"=> 1, "value"=>"Great"}, {"id"=>@question.id, "keypad"=>2, "value"=>"Super"}])
        caller_session.gather_response.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/submit_response?question_id=#{@question.id}&amp;question_number=0&amp;session_id=#{caller_session.id}\" method=\"POST\"><Say>How do you like Impactdialing</Say><Say>press 1 for Great</Say><Say>press 2 for Super</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
      end
    end
  end

  describe "conference_started_phones_only_predictive" do

    describe "gather_response to read_next_question" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:predictive, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script, text: "How do you like Impactdialing")
      end


      it "should render correct twiml" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "conference_started_phones_only", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt, question_number: 0, script_id: @script.id)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0})
        RedisQuestion.should_receive(:get_question_to_read).with(@script.id, caller_session.question_number).and_return({"id"=> @question.id, "question_text"=> "How do you like Impactdialing"})
        RedisPossibleResponse.should_receive(:possible_responses).and_return([{"id"=>@question.id, "keypad"=> 1, "value"=>"Great"}, {"id"=>@question.id, "keypad"=>2, "value"=>"Super"}])
        caller_session.should_receive(:call_answered?).and_return(true)
        caller_session.gather_response.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/submit_response?question_id=#{@question.id}&amp;question_number=0&amp;session_id=#{caller_session.id}\" method=\"POST\"><Say>How do you like Impactdialing</Say><Say>press 1 for Great</Say><Say>press 2 for Super</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
      end
    end
    
    describe "run out of phone numbers" do
      
      it "should render hangup twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "conference_started_phones_only_predictive", voter_in_progress: nil)
        caller_session.campaign_out_of_phone_numbers.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>This campaign has run out of phone numbers.</Say><Hangup/></Response>")
      end
      
    end
    
  end


  describe "read_next_question" do

    describe "disconnected" do

      before(:each) do
        @script = create(:script)
        @campaign =  create(:progressive, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script)
      end


      it "render correct twiml" do
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        caller_session.should_receive(:disconnected?).and_return(true)
        caller_session.submit_response.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      end

    end

     describe "wrapup_call" do

      before(:each) do
        @script = create(:script)
        @campaign =  create(:progressive, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script)
      end

      it "render correct twiml" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:disconnected?).and_return(false)
        caller_session.should_receive(:skip_all_questions?).and_return(true)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        caller_session.submit_response.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/next_call?session_id=#{caller_session.id}</Redirect></Response>")
      end

      end

    describe "voter response" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:progressive, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @voter = create(:voter)
        @question = create(:question, script: @script)
      end


      it "should persist the answer " do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", question_id: @question.id, attempt_in_progress: call_attempt, voter_in_progress: @voter, digit: 1)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        caller_session.should_receive(:disconnected?).and_return(false)
        RedisPhonesOnlyAnswer.should_receive(:push_to_list).with(@voter.id, caller_session.id, 1, 1)
        caller_session.submit_response
      end

      it "should render correct twiml " do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: true, available_for_call: false, campaign: @campaign, state: "read_next_question", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt, question_number: 0)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        caller_session.should_receive(:disconnected?).and_return(false)        
        caller_session.submit_response.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/next_question?question_number=1&amp;session_id=#{caller_session.id}</Redirect></Response>")
      end

    end
  end

  describe "voter_response" do
    before(:each) do
      @script = create(:script)
      @campaign =  create(:progressive, script: @script)
      @caller = create(:caller, campaign: @campaign)
      @voter = create(:voter)
       @question = create(:question, script: @script, text: "How do you like Impactdialing")
    end

    describe "more_questions_to_be_answered" do
      
      it "should move to read_next_question state" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "voter_response", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt, script_id: @script.id)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        RedisQuestion.should_receive(:get_question_to_read).with(@script.id, caller_session.redis_question_number).and_return({"id"=> @question.id, "question_text"=> "How do you like Impactdialing"})
        RedisPossibleResponse.should_receive(:possible_responses).and_return([{"id"=>@question.id, "keypad"=> 1, "value"=>"Great"}, {"id"=>@question.id, "keypad"=>2, "value"=>"Super"}])        
        caller_session.should_receive(:more_questions_to_be_answered?).and_return(true)
        caller_session.next_question.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/submit_response?question_id=#{@question.id}&amp;question_number=0&amp;session_id=#{caller_session.id}\" method=\"POST\"><Say>How do you like Impactdialing</Say><Say>press 1 for Great</Say><Say>press 2 for Super</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
      end

    end

    describe "no_more_questions_to_be_answered" do
      it "should move to read_next_question state" do
        call_attempt = create(:call_attempt, voter: @voter)
        caller_session = create(:phones_only_caller_session, caller: @caller, on_call: false, available_for_call: false, campaign: @campaign, state: "voter_response", voter_in_progress: @voter, question_id: @question.id, attempt_in_progress: call_attempt)
        caller_session.should_receive(:more_questions_to_be_answered?).and_return(false)
        RedisCallerSession.set_request_params(caller_session.id, {digit: 1, question_number: 0, question_id: 1})
        RedisStatus.should_receive(:set_state_changed_time).with(@campaign.id, "On hold",caller_session.id)
        caller_session.next_question.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/next_call?session_id=#{caller_session.id}</Redirect></Response>")
      end

    end
  end

end