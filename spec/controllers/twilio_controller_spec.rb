require "spec_helper"

describe TwilioController do
  it "proceeds with the call if the call was answered" do
    recording = Factory(:robo_recording, :file_file_name => 'foo.wav')
    call_attempt = Factory(:call_attempt, :campaign => Factory(:campaign, :script => Factory(:script, :robo_recordings => [recording])), :voter => Factory(:voter))
    post :callback, :call_attempt_id => call_attempt.id, :CallStatus => 'in-progress'
    response.body.should == recording.twilio_xml(call_attempt)
  end

  ['queued', 'busy', 'failed', 'no-answer', 'canceled', ].each do |call_status|
    it "hangs up if the call has a status of #{call_status}" do
      recording = Factory(:robo_recording, :file_file_name => 'foo.wav')
      call_attempt = Factory(:call_attempt, :campaign => Factory(:campaign, :script => Factory(:script, :robo_recordings => [recording])), :voter => Factory(:voter))
      post :callback, :call_attempt_id => call_attempt.id, :CallStatus => call_status
      response.body.should == Twilio::Verb.hangup
    end
  end
end
