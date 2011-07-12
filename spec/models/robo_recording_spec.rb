require "spec_helper"

describe RoboRecording do
  include ActionController::UrlWriter

  describe "next recording in the script" do
    it "return the next recording in the script" do
      script = Factory(:script)
      recording1 = Factory(:robo_recording, :script => script)
      recording2 = Factory(:robo_recording, :script => script)
      recording3 = Factory(:robo_recording, :script => script)
      recording1.next.should == recording2
      recording2.next.should == recording3
    end

    it "returns nil for no existing next recording for this script" do
      script = Factory(:script)
      recording1 = Factory(:robo_recording, :script => script)
      recording2 = Factory(:robo_recording, :script => script)
      recording3 = Factory(:robo_recording, :script => Factory(:script))
      recording1.next.should == recording2
      recording2.next.twilio_xml.should == Twilio::Verb.new(&:hangup).response
    end
  end

  it "gives the appropriate recording response for the given digit" do
    robo_recording = Factory(:robo_recording)
    recording_response1 = Factory(:recording_response, :robo_recording => robo_recording, :keypad => "42", :response => "answer to everything")
    recording_response2 = Factory(:recording_response, :robo_recording => robo_recording, :keypad => "21", :response => "half the answer to everything")
    robo_recording.response_for("42").should == recording_response1
  end

  describe "twilio responses" do

    before :each do
      @twilio_response = mock
      @twilio_response.stub!(:response)
      @robo_recording = Factory(:robo_recording)
    end

    it "presents an IVR prompt if the recording expects a response" do
      Factory(:recording_response, :robo_recording => @robo_recording, :response => "hakkuna mathatha", :keypad => "1")
      @robo_recording.should_receive(:ivr_prompt).and_return(@twilio_response)
      @robo_recording.should_not_receive(:play_message)
      @robo_recording.twilio_xml(Factory(:call_attempt))
    end

    it "plays a message if the recording does not expect any response" do
      @robo_recording.should_not_receive(:ivr_prompt)
      @robo_recording.should_receive(:play_message).and_return(@twilio_response)
      @robo_recording.twilio_xml(Factory(:call_attempt))
    end

  end

  describe "play messages continuously" do

    before(:each) do
      @script = Factory(:script)
      @campaign = Factory(:campaign, :script => @script)
      @call_attempt = Factory(:call_attempt, :campaign => @campaign)
    end

    it "plays all messages without any expected responses one after the other" do
      recording1 = Factory(:robo_recording, :script => @script, :file_file_name => "foo.mp3")
      recording2 = Factory(:robo_recording, :script => @script, :file_file_name => "bar.mp3")
      recording1.twilio_xml(@call_attempt).should == Twilio::Verb.new { |v| [recording1, recording2].each { |r| v.play URI.escape r.file.url } }.response
    end

    it "plays all messages without any expected responses one after the other upto a recording that expects a response" do
      recording1 = Factory(:robo_recording, :script => @script, :file_file_name => "foo.mp3")
      recording2 = Factory(:robo_recording, :script => @script, :file_file_name => "bar.mp3", :recording_responses => [Factory(:recording_response)])
      recording3 = Factory(:robo_recording, :script => @script, :file_file_name => "robo.mp3")

      expected = Twilio::Verb.new do |v|
        v.play URI.escape recording1.file.url;
        recording2.prompt_message(call_attempts_url(:host => HOST, :id => @call_attempt.id, :robo_recording_id => recording2.id), v)
      end

      recording1.twilio_xml(@call_attempt).should == expected.response
    end
  end

end
