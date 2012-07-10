require "spec_helper"

describe ModeratorCampaign do
  
  it "should initilaize moderator campaign with campaign values" do
    account = Factory(:account)
    moderator = Factory(:moderator)
    moderator_campaign = ModeratorCampaign.new(account.id, moderator.id, 6,1,2,3,2,7)
  end
  
  it "should increment callers logged in" do
    account = Factory(:account)
    moderator = Factory(:moderator)
    moderator_campaign = ModeratorCampaign.new(account.id, moderator.id, 6,1,2,3,2,7)
    moderator_campaign.increment_callers_logged_in(2)
    moderator_campaign.callers_logged_in.should eq(7)
  end
  
  
end