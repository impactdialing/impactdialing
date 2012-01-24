require "spec_helper"

describe RecordingResponse do
  
  it "returns the calculated percentage value for possible response" do
    now = Time.now
    campaign = Factory(:campaign)
    robo_recording = Factory(:robo_recording, :script => Factory(:script))
    recording_response = Factory(:recording_response, :robo_recording => robo_recording)
    call_response = Factory(:call_response, :call_attempt => Factory(:call_attempt, :campaign => campaign), campaign: campaign,:recording_response => recording_response, :robo_recording => robo_recording, :created_at => now)
    recording_response.stats(now, now, 25, campaign).should == {answer: "response", number: 1, percentage:  4}
  end
  
end
