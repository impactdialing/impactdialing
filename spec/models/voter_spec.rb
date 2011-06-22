require "spec_helper"

describe Voter do
  it "should list existing entries in a campaign having the given phone number" do
    lambda {
      Factory(:voter, :Phone => '0123456789', :campaign_id => 99)
    }.should change {
      Voter.existing_phone_in_campaign('0123456789', 99).count
    }.by(1)
  end

  it "returns only active voters" do
    active_voter = Factory(:voter, :active => true)
    inactive_voter = Factory(:voter, :active => false)
    Voter.active.should == [active_voter]
  end
end
