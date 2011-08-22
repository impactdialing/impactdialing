require "spec_helper"

describe CallResponse do
  it "logs and return a valid call response" do
    robo_recording = Factory(:robo_recording)
    recording_response = Factory(:recording_response, :robo_recording => robo_recording, :response => 'test', :keypad => '1')
    call_attempt = Factory(:call_attempt)
    CallResponse.log_response(call_attempt, robo_recording,1).recording_response.should == recording_response
  end

  it "does not capture a recording response for an invalid call response" do
    robo_recording = Factory(:robo_recording)
    recording_response = Factory(:recording_response, :robo_recording => robo_recording, :response => 'test', :keypad => '1')
    call_attempt = Factory(:call_attempt)
    CallResponse.log_response(call_attempt, robo_recording,2).recording_response.should be_nil
  end

  it "increments call_attempts" do
    robo_recording = Factory(:robo_recording)
    recording_response = Factory(:recording_response, :robo_recording => robo_recording, :response => 'test', :keypad => '1')
    call_attempt = Factory(:call_attempt)
    CallResponse.log_response(call_attempt, robo_recording,2).times_attempted.should == 1
    CallResponse.log_response(call_attempt, robo_recording,2).times_attempted.should == 2
    CallResponse.log_response(call_attempt, robo_recording,2).times_attempted.should == 3
  end
end
