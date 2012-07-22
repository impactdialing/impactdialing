require "spec_helper"

describe MonitorSession do
  
  it "should add session to campaign set" do
    campaign = Factory(:campaign)
    MonitorSession.add_session(campaign.id)
    MonitorSession.sessions(campaign.id).size.should eq(1)
  end
  
  it "should add 2 session to the same campaign set" do
    campaign = Factory(:campaign)
    MonitorSession.add_session(campaign.id)
    MonitorSession.add_session(campaign.id)
    MonitorSession.sessions(campaign.id).size.should eq(2)
  end
  
  it "should remove a session from campaign set" do
    campaign = Factory(:campaign)
    MonitorSession.should_receive(:generate_session_key).and_return("1234567")
    MonitorSession.add_session(campaign.id)
    MonitorSession.remove_session(campaign.id, "1234567")
    MonitorSession.sessions(campaign.id).size.should eq(0)
  end
  
end