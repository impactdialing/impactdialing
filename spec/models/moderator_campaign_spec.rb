require "spec_helper"

describe ModeratorCampaign do
  
  before(:each) do
    @campaign = Factory(:predictive)
    @moderator_campaign = ModeratorCampaign.new(@campaign.id, 5, 2, 3, 2, 7, 3, 100, 300)
  end
  
  it "should increment callers logged in" do
    ModeratorCampaign.increment_callers_logged_in(@campaign.id, 2)
    ModeratorCampaign.callers_logged_in(@campaign.id).should eq("7")
  end
  
  it "should decrement callers logged in" do
    ModeratorCampaign.decrement_callers_logged_in(@campaign.id, 2)
    ModeratorCampaign.callers_logged_in(@campaign.id).should eq("3")
  end

  it "should increment on call" do
    ModeratorCampaign.increment_on_call(@campaign.id, 2)
    ModeratorCampaign.on_call(@campaign.id).should eq("4")
  end
  
  it "should decrement on call" do
    ModeratorCampaign.decrement_on_call(@campaign.id, 1)
    ModeratorCampaign.on_call(@campaign.id).should eq("1")
  end

  it "should increment on hold" do
    ModeratorCampaign.increment_on_hold(@campaign.id, 2)
    ModeratorCampaign.on_hold(@campaign.id).should eq("4")
  end
  
  it "should decrement on hold" do
    ModeratorCampaign.decrement_on_hold(@campaign.id, 1)
    ModeratorCampaign.on_hold(@campaign.id).should eq("1")
  end
  
  
  
end