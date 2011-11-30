require "spec_helper"

describe Account do
  it "returns the activated status as the paid flag" do
    Factory(:account, :activated => true).paid?.should be_true
    Factory(:account, :activated => false).paid?.should be_false
  end
  
  it "can toggle the call_recording setting" do
    account = Factory(:account, :record_calls => true)
    account.record_calls?.should be_true
    account.toggle_call_recording!
    account.record_calls?.should be_false
    account.toggle_call_recording!
    account.record_calls?.should be_true
  end
end
