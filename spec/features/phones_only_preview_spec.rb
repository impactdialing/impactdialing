require "integration_spec_helper"

describe "PhonesOnlyPreview" do

  describe "ask for pin" do
    it "should ask for caller pin when caller dials in" do
      conn = Faraday.new(:url => 'http://localhost:3000')
      response = conn.post '/callin/create'
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=1\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Please enter your pin and then press star.</Say></Gather><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=1\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Please enter your pin and then press star.</Say></Gather><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=1\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Please enter your pin and then press star.</Say></Gather></Response>")
    end

    it "should ask for caller pin again if pin not correct" do
      conn = Faraday.new(:url => 'http://localhost:3000')
      caller = Factory.create(:caller, is_phones_only: true)
      response = conn.post '/callin/identify?attempt=1', { Digits: "12345" }
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=2\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Incorrect Pin. Please enter your pin and then press star.</Say></Gather><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=2\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Incorrect Pin. Please enter your pin and then press star.</Say></Gather><Gather finishOnKey=\"*\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/identify_caller?attempt=2\" method=\"POST\"><Say voice=\"man\" language=\"en\" loop=\"1\">Incorrect Pin. Please enter your pin and then press star.</Say></Gather></Response>")
    end

    it "should say incorrect pin and hangup if more than 3 tries" do
      conn = Faraday.new(:url => 'http://localhost:3000')
      caller = Factory.create(:caller, is_phones_only: true, pin: "12345")
      response = conn.post '/callin/identify?attempt=3', { Digits: "12345" }
      response.body.should eq( "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">Incorrect Pin.</Say><Hangup/></Response>")
    end

    it "should create conference if pin correct" do
      conn = Faraday.new(:url => 'http://localhost:3000')
      caller = Factory.create(:caller, is_phones_only: true)
      response = conn.post '/callin/identify?attempt=1', { Digits:  caller.pin}
      response.body.should eq( "<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Gather numDigits=\"1\" timeout=\"10\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/read_instruction_options?session_id=#{caller.caller_sessions.first.id}\" method=\"POST\" finishOnKey=\"5\"><Say>Press star to begin dialing or pound for instructions.</Say></Gather></Response>")
    end
  end

  describe "read instructions " do
    it "should read instructions to caller" do
      conn = Faraday.new(:url => 'http://localhost:3000')
      caller = Factory.create(:caller, is_phones_only: true)
      conn.post '/callin/identify?attempt=1', { Digits:  caller.pin}
      response = conn.post "caller/#{caller.id}/read_instruction_options?session_id=#{caller.caller_sessions.first.id}", { Digits:  "#"}
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>After these instructions, you will be placed on hold. When someone answers the phone, the hold music will stop. You usually won't hear the person say hello, so start talking immediately. At the end of the conversation, do not hang up your phone. Instead, press star to end the call, and you will be given instructions on how to enter your call results.</Say><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/1/callin_choice?session_id=1</Redirect></Response>")
    end
  end

  describe "start calling " do
    it "should redirect to ready to call " do
      conn = Faraday.new(:url => 'http://localhost:3000')
      caller = Factory.create(:caller, is_phones_only: true)
      conn.post '/callin/identify?attempt=1', { Digits:  caller.pin}
      response = conn.post "caller/#{caller.id}/read_instruction_options?session_id=#{caller.caller_sessions.first.id}", { Digits:  "*"}
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/ready_to_call?session_id=#{caller.caller_sessions.first.id}</Redirect></Response>")
    end

    it "should redirect to ready to call " do
      conn = Faraday.new(:url => 'http://localhost:3000')
      preview_campaign = Factory(:preview)
      caller = Factory.create(:caller, is_phones_only: true)
      conn.post '/callin/identify?attempt=1', { Digits:  caller.pin}
      response = conn.post "caller/#{caller.id}/read_instruction_options?session_id=#{caller.caller_sessions.first.id}", { Digits:  "*"}
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Redirect>http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/ready_to_call?session_id=#{caller.caller_sessions.first.id}</Redirect></Response>")
    end
  end

end