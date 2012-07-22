require "spec_helper"

describe ModeratorSession do
  
  it "should add session to campaign set" do
    campaign = Factory(:campaign)
    ModeratorSession.add_session(campaign.id)
    ModeratorSession.sessions(campaign.id).size.should eq(1)
  end
  
  it "should add 2 session to the same campaign set" do
    campaign = Factory(:campaign)
    ModeratorSession.add_session(campaign.id)
    ModeratorSession.add_session(campaign.id)
    ModeratorSession.sessions(campaign.id).size.should eq(2)
  end
  
  it "should remove a session from campaign set" do
    campaign = Factory(:campaign)
    ModeratorSession.should_receive(:generate_session_key).and_return("1234567")
    ModeratorSession.add_session(campaign.id)
    ModeratorSession.remove_session(campaign.id, "1234567")
    ModeratorSession.sessions(campaign.id).size.should eq(0)
  end
  
end