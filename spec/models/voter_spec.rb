require "spec_helper"

describe Voter do
  it "should list existing entries in a voters list having the given phone number" do
    lambda {
      Factory(:voter, :Phone => '0123456789', :voter_list_id => 99)
    }.should change {
      Voter.existing_phone('0123456789', 99).count
    }.by(1)
  end
end
