require "integration_spec_helper"
require "twilio_helper"
require "twilio_proxy"


describe "PhonesOnlyPower" do
  include TwilioHelper
  before(:each) do
    @twilio_proxy = TwilioProxy.new
    @conn = Faraday.new(:url => 'http://localhost:3000')
  end

  describe "ask for pin" do

    before(:each) do
      @caller = Factory.create(:caller, is_phones_only: true)
    end

    it "should ask for caller pin when caller dials in" do
      response =  @twilio_proxy.callin(true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=1\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Please enter your pin and then press star.</Say></Gather><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=1\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Please enter your pin and then press star.</Say></Gather><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=1\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Please enter your pin and then press star.</Say></Gather></Response>")
    end

    it "should ask for caller pin again if pin not correct" do
      response = @twilio_proxy.identify("12345", true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=2\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Incorrect Pin. Please enter your pin and then press star.</Say></Gather><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=2\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Incorrect Pin. Please enter your pin and then press star.</Say></Gather><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=2\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Incorrect Pin. Please enter your pin and then press star.</Say></Gather></Response>")
    end

    it "should say incorrect pin and hangup if more than 3 tries" do
      response = @conn.post '/callin/identify?attempt=3', { Digits: "12345" }
      response.body.should eq( "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">Incorrect Pin.</Say><Hangup/></Response>")
    end

    it "should create conference if pin correct" do
      response = @twilio_proxy.identify(@caller.pin, true)
      response.body.should eq( "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/read_instruction_options?session_id=#{@caller.caller_sessions.first.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
    end
  end

  describe "read instructions " do

    before(:each) do
      @caller = Factory.create(:caller, is_phones_only: true)
    end

    it "should read instructions to caller" do
      response = @twilio_proxy.read_instruction_options(@caller, "#", true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>After these instructions, you will be placed on hold. When someone answers the phone, the hold music will stop. You usually won't hear the person say hello, so start talking immediately. At the end of the conversation, do not hang up your phone. Instead, press star to end the call, and you will be given instructions on how to enter your call results.</Say><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/callin_choice?session_id=#{@caller.caller_sessions.first.id}</Redirect></Response>")
    end
  end

  describe "start calling " do
    before(:each) do
      @power_campaign = Factory(:progressive)
      @caller = Factory.create(:caller, is_phones_only: true, campaign: @power_campaign)
    end

    it "should redirect to ready to call " do
      response = @twilio_proxy.read_instruction_options(@caller, "*", true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/ready_to_call?session_id=#{@caller.caller_sessions.first.id}</Redirect></Response>")
    end


    it "should read no more voters to dial if campaign out of voters " do
      response = @twilio_proxy.ready_to_call(@caller, true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no more numbers to call in this campaign.</Say><Hangup/></Response>")
    end

    it "should read voters name to caller " do
      voter = Factory(:voter, campaign: @power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890")
      response = @twilio_proxy.ready_to_call(@caller, true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>John  Doe.</Say><Redirect method=\"POST\">http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{@caller.id}/conference_started_phones_only_power?session_id=#{@caller.caller_sessions.first.id}&amp;voter_id=#{voter.id}</Redirect></Response>")
    end

  end

  describe "power calling job" do

    it "should start power call job and redirect caller as account not funded " do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::PER_MINUTE)
      power_campaign = Factory(:progressive)
      voter = Factory(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_redirect_account_has_no_funds(caller, caller.caller_sessions.first)
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      response = @twilio_proxy.redirect_account_out_of_funds(caller)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>There are no funds available in the account.  Please visit the billing area of the website to add funds to your account.</Say><Hangup/></Response>")
    end

    it "should start power call job and redirect caller as time period exceeded " do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now - 1.hours))
      voter = Factory(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_redirect_campaign_time_period_exceeded(caller, caller.caller_sessions.first)
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      response = @twilio_proxy.redirect_time_period_exceeded(caller)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 12 AM and 1 PM. Please try back during those hours.</Say><Hangup/></Response>")
    end

    it "should start power call job and handle failed call " do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 10.hours), end_time: (Time.now + 8.hours), time_zone: "Mumbai")
      voter = Factory(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_failed
      mock_redirect_caller_phones_only(caller, caller.caller_sessions.first)
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      CallAttempt.first.status.should eq("Call failed")
    end

    it "should start power call job and handle successful call" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 8.hours), time_zone: "Mumbai")
      voter = Factory(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      CallAttempt.first.sid.should eq("12345")
    end
  end

  describe "incoming call" do

    it "should abandon call if caller disconnects before call connecting" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours), time_zone: "Mumbai")
      voter = Factory(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      caller.caller_sessions.first.update_attributes(on_call: false, available_for_call: false)
      call = Call.first
      response = @twilio_proxy.incoming_call(call, "human", "in-progress", "power", true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      $redis_call_flow_connection.llen("abandoned_call_list").should eq(1)
    end

    it "should redirect caller if call answered by machine" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours), time_zone: "Mumbai")
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      response = @twilio_proxy.incoming_call(call, "machine", "in-progress", "power",true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end

    it "should connect call if answered by human and caller available" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours), time_zone: "Mumbai")
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      response = @twilio_proxy.incoming_call(call, "human", "in-progress", "power", true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"false\" action=\"http://#{Settings.twilio_callback_host}/calls/#{call.id}/disconnected\" record=\"false\"><Conference waitUrl=\"hold_music\" waitMethod=\"GET\" beep=\"false\" endConferenceOnExit=\"true\">#{caller.caller_sessions.first.session_key}</Conference></Dial></Response>")
    end

  end

  describe "incoming call disconnected" do
    it "should disconnect call when twilio post disconnect url" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours), time_zone: "Mumbai")
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      response = @twilio_proxy.disconect_call(call, true, "power")
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      $redis_call_flow_connection.llen("disconnected_call_list").should eq(1)
    end
  end

  describe "call end" do
    it "should process not answered calls" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours), time_zone: "Mumbai")
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      response = @twilio_proxy.call_ended(call, nil, "no-answer", "power", true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      $redis_call_end_connection.llen("not_answered_call_list").should eq(1)
    end

    it "should process calls answered by machines" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours), time_zone: "Mumbai")
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      response = @twilio_proxy.call_ended(call, "machine", nil, "power", true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
      $redis_call_end_connection.llen("end_answered_by_machine_call_list").should eq(1)
    end
  end

  describe "caller gather response flow" do
    it "should present first question" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      script = Factory.create(:script)
      question = Factory.create(:question)
      script.questions << question
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours),
       time_zone: "Mumbai", script: script)
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      @twilio_proxy.disconect_call(call, "power", false)
      @twilio_proxy.call_ended(call, "human", nil, "power", false)
      RedisQuestion.persist_questions(script.id, question.id, "Whats your name???")
      RedisPossibleResponse.persist_possible_response(question.id, "1", "John Doe")
      response = @twilio_proxy.gather_response(caller, 0, true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/submit_response?question_id=#{question.id}&amp;question_number=0&amp;session_id=#{caller.caller_sessions.first.id}\" method=\"POST\"><Say>Whats your name???</Say><Say>press 1 for John Doe</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
    end

     it "should submit response" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      script = Factory.create(:script)
      question = Factory.create(:question)
      script.questions << question
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours),
       time_zone: "Mumbai", script: script)
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      @twilio_proxy.disconect_call(call, "power", false)
      @twilio_proxy.call_ended(call, "human", nil, false)
      RedisQuestion.persist_questions(script.id, question.id, "Whats your name???")
      RedisPossibleResponse.persist_possible_response(question.id, "1", "John Doe")
      @twilio_proxy.gather_response(caller, 0, false)
      response = @twilio_proxy.submit_response(caller, question, 1, true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/next_question?question_number=1&amp;session_id=#{caller.caller_sessions.first.id}</Redirect></Response>")
    end

     it "should submit response and get next question" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      script = Factory.create(:script)
      question1 = Factory.create(:question)
      question2 = Factory.create(:question)
      script.questions << question1
      script.questions << question2
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours),
       time_zone: "Mumbai", script: script)
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      @twilio_proxy.disconect_call(call, "power", false)
      @twilio_proxy.call_ended(call, "human", nil, "power", false)
      RedisQuestion.persist_questions(script.id, question2.id, "Whats your age???")
      RedisQuestion.persist_questions(script.id, question1.id, "Whats your name???")
      RedisPossibleResponse.persist_possible_response(question1.id, "1", "John Doe")
      RedisPossibleResponse.persist_possible_response(question2.id, "1", "99")
      @twilio_proxy.gather_response(caller, 0, false)
      @twilio_proxy.submit_response(caller, question1, 1)
      response = @twilio_proxy.next_question(caller, 1, true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather timeout=\"60\" finishOnKey=\"*\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/submit_response?question_id=#{question2.id}&amp;question_number=1&amp;session_id=#{caller.caller_sessions.first.id}\" method=\"POST\"><Say>Whats your age???</Say><Say>press 1 for 99</Say><Say>Then press star to submit your result.</Say></Gather></Response>")
    end

    it "should ask for next question and if none exist move to next call" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      script = Factory.create(:script)
      question1 = Factory.create(:question)
      question2 = Factory.create(:question)
      script.questions << question1
      script.questions << question2
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours),
       time_zone: "Mumbai", script: script)
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      @twilio_proxy.disconect_call(call, "power", false)
      @twilio_proxy.call_ended(call, "human", nil, "power", false)
      RedisQuestion.persist_questions(script.id, question2.id, "Whats your age???")
      RedisQuestion.persist_questions(script.id, question1.id, "Whats your name???")
      RedisPossibleResponse.persist_possible_response(question1.id, "1", "John Doe")
      RedisPossibleResponse.persist_possible_response(question2.id, "1", "99")
      @twilio_proxy.gather_response(caller, 0, false)
      @twilio_proxy.submit_response(caller, question1, 1)
      @twilio_proxy.next_question(caller, 1, true)
      @twilio_proxy.submit_response(caller, question2, 1, true)
      response = @twilio_proxy.next_question(caller, 2, true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/next_call?session_id=#{caller.caller_sessions.first.id}</Redirect></Response>")
    end

    it "should redirect to ready to call for next call" do
      account = Factory.create(:account, subscription_name: Account::Subscription_Type::MANUAL)
      script = Factory.create(:script)
      question1 = Factory.create(:question)
      question2 = Factory.create(:question)
      script.questions << question1
      script.questions << question2
      power_campaign = Factory(:progressive, account: account, start_time: (Time.now - 2.hours), end_time: (Time.now + 6.hours),
       time_zone: "Mumbai", script: script)
      voter = Factory.create(:voter, campaign: power_campaign, FirstName: "John", LastName: "Doe", Phone: "1234567890", account: account)
      caller = Factory.create(:caller, is_phones_only: true, campaign: power_campaign, account: account)
      @twilio_proxy.conference_started_phones_only_power(caller, voter, false)
      mock_make_call_as_success
      PreviewPowerDialJob.new.perform(caller.caller_sessions.first.id, voter.id)
      call = Call.first
      @twilio_proxy.disconect_call(call, "power", false)
      @twilio_proxy.call_ended(call, "human", nil, "power",  false)
      RedisQuestion.persist_questions(script.id, question2.id, "Whats your age???")
      RedisQuestion.persist_questions(script.id, question1.id, "Whats your name???")
      RedisPossibleResponse.persist_possible_response(question1.id, "1", "John Doe")
      RedisPossibleResponse.persist_possible_response(question2.id, "1", "99")
      @twilio_proxy.gather_response(caller, 0, false)
      @twilio_proxy.submit_response(caller, question1, 1)
      @twilio_proxy.next_question(caller, 1)
      @twilio_proxy.submit_response(caller, question2, 1)
      @twilio_proxy.next_question(caller, 2)
      response = @twilio_proxy.next_call(caller, true)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>John  Doe.</Say><Redirect method=\"POST\">http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/conference_started_phones_only_power?session_id=#{caller.caller_sessions.first.id}&amp;voter_id=#{voter.id}</Redirect></Response>")
    end



  end

end