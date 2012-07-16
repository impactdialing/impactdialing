require "spec_helper"

describe ModeratorCampaign do
  
  before(:each) do
    @campaign = Factory(:campaign)
    @moderator_campaign = ModeratorCampaign.new(@campaign.id,5,2,3,2,7,3)    
  end
  
  
  it "should increment callers logged in" do
    @moderator_campaign.increment_callers_logged_in(2)
    @moderator_campaign.callers_logged_in.value.should eq(7)
  end
  
  it "should decrement callers logged in" do
    @moderator_campaign.decrement_callers_logged_in(2)
    @moderator_campaign.callers_logged_in.value.should eq(3)
  end

  it "should increment callers on call" do
    @moderator_campaign.increment_on_call(2)
    @moderator_campaign.on_call.value.should eq(4)
  end
  
  it "should decrement callers logged in" do
    @moderator_campaign.decrement_on_call(1)
    @moderator_campaign.on_call.value.should eq(1)
  end

  it "should increment callers on hold" do
    @moderator_campaign.increment_on_hold(2)
    @moderator_campaign.on_hold.value.should eq(4)
  end
  
  it "should decrement callers on hold" do
    @moderator_campaign.decrement_on_hold(1)
    @moderator_campaign.on_hold.value.should eq(1)
  end

  
  
  
end