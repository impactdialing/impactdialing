require "spec_helper"

describe RoboRecording do

  describe "next recording in the script" do
    it "return the next recording in the script" do
      script = Factory(:script)
      recording1 = Factory(:robo_recording, :script => script)
      recording2 = Factory(:robo_recording, :script => script)
      recording3 = Factory(:robo_recording, :script => script)
      recording1.next.should == recording2
      recording2.next.should == recording3
    end

    it "returns nil if there are no more recordings for this script" do
      script = Factory(:script)
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
end
