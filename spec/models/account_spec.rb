require "spec_helper"

describe Account do
  it "returns the activated status as the paid flag" do
    Factory(:account, :activated => true).paid?.should be_true
    Factory(:account, :activated => false).paid?.should be_false
  end
end
