require "spec_helper"

describe MonitorCampaign do
  
  before(:each) do
    @campaign = Factory(:predictive)
    @moderator_campaign = MonitorCampaign.new(@campaign.id, 5, 2, 3, 2, 7, 3, 100, 300)
  end
  
  it "should increment callers logged in" do
    MonitorCampaign.increment_callers_logged_in(@campaign.id, 2)
    MonitorCampaign.callers_logged_in(@campaign.id).should eq("7")
  end
  
  it "should decrement callers logged in" do
    MonitorCampaign.decrement_callers_logged_in(@campaign.id, 2)
    MonitorCampaign.callers_logged_in(@campaign.id).should eq("3")
  end

  it "should increment on call" do
    MonitorCampaign.increment_on_call(@campaign.id, 2)
    MonitorCampaign.on_call(@campaign.id).should eq("4")
  end
  
  it "should decrement on call" do
    MonitorCampaign.decrement_on_call(@campaign.id, 1)
    MonitorCampaign.on_call(@campaign.id).should eq("1")
  end

  it "should increment on hold" do
    MonitorCampaign.increment_on_hold(@campaign.id, 2)
    MonitorCampaign.on_hold(@campaign.id).should eq("4")
  end
  
  it "should decrement on hold" do
    MonitorCampaign.decrement_on_hold(@campaign.id, 1)
    MonitorCampaign.on_hold(@campaign.id).should eq("1")
  end
  
  
  
end