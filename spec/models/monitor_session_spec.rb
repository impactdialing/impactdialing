require "spec_helper"

describe MonitorSession, :type => :model do
  
  it "should add session to campaign set" do
    campaign = create(:campaign)
    MonitorSession.add_session(campaign.id)
    expect(MonitorSession.sessions(campaign.id).size).to eq(1)
  end
  
  it "should add 2 session to the same campaign set" do
    campaign = create(:campaign)
    MonitorSession.add_session(campaign.id)
    MonitorSession.add_session(campaign.id)
    expect(MonitorSession.sessions(campaign.id).size).to eq(2)
  end
  
  it "should remove a session from campaign set" do
    campaign = create(:campaign)
    expect(MonitorSession).to receive(:generate_session_key).and_return("1234567")
    MonitorSession.add_session(campaign.id)
    MonitorSession.remove_session(campaign.id, "1234567")
    expect(MonitorSession.sessions(campaign.id).size).to eq(0)
  end
  
end