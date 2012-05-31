require "spec_helper"

describe RoboRecording do
  include Rails.application.routes.url_helpers
  
  let(:script) { Factory(:script) }
  let(:campaign) { Factory(:campaign, :script => script) }
  let(:call_attempt) { Factory(:call_attempt)}
  let(:voter) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt) }

  
  it "should return questions answered in a time range" do
    now = Time.now
    robo_recording = Factory(:robo_recording, :script => script)
    recording_response = Factory(:recording_response, :robo_recording => robo_recording)
    call_response1 = Factory(:call_response, :call_attempt => Factory(:call_attempt), campaign: campaign, :recording_response => recording_response, :robo_recording => robo_recording, :created_at => (now - 2.days))
    call_response2 = Factory(:call_response, :call_attempt => Factory(:call_attempt), campaign: campaign, :recording_response => recording_response, :robo_recording => robo_recording, :created_at => (now - 1.days))
    call_response3 = Factory(:call_response, :call_attempt => Factory(:call_attempt), campaign: campaign, :recording_response => recording_response, :robo_recording => robo_recording, :created_at => (now + 1.minute))
    call_response4 = Factory(:call_response, :call_attempt => Factory(:call_attempt), campaign: campaign, :recording_response => recording_response, :robo_recording => robo_recording, :created_at => (now + 1.day))
    robo_recording.answered_within(now, now + 1.day, campaign.id).should == [call_response3, call_response4]
    robo_recording.answered_within(now + 2.days, now + 3.days, campaign.id).should == []
  end
  
  it "returns robo_recordings answered by a voter" do
    responded_recording = Factory(:robo_recording, :script => script, :name => "Q1?")
    pending_recording = Factory(:robo_recording, :script => script, :name => "Q2?")
    Factory(:call_response, :call_attempt => call_attempt, :recording_response => Factory(:recording_response), :robo_recording => responded_recording, :created_at => (Time.now - 2.days))
    RoboRecording.responded_by(voter).should == [responded_recording]
  end

  it "returns all robo_recordings, which are not responded by voter" do
    r1 = Factory(:robo_recording, :script => script, :name => "Q1?")
    r2 = Factory(:robo_recording, :script => script, :name => "Q2?")
    script.robo_recordings.not_responded_by(voter).should == [r1, r2]
  end

  describe "next recording in the script" do
    it "return the next recording in the script" do
      recording1 = Factory(:robo_recording, :script => script)
      recording2 = Factory(:robo_recording, :script => script)
      recording3 = Factory(:robo_recording, :script => script)
      recording1.next.should == recording2
      recording2.next.should == recording3
    end

    it "returns nil for no existing next recording for this script" do
      recording1 = Factory(:robo_recording, :script => script)
      recording2 = Factory(:robo_recording, :script => script)
      recording3 = Factory(:robo_recording, :script => Factory(:script))
      recording1.next.should == recording2
      recording2.next.should be_nil
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
        recording2.prompt_message(twilio_create_call_url(:host => Settings.host, :id => @call_attempt.id, :robo_recording_id => recording2.id), v)
      end

      recording1.twilio_xml(@call_attempt).should == expected.response
    end
  end

end
