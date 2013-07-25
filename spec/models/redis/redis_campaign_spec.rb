require "spec_helper"

describe RedisPredictiveCampaign do
  
  
  it "should add to running campaigns" do
    account = create(:account)
    campaign = create(:predictive, name: "test123", account: account)
    RedisPredictiveCampaign.add(campaign.id, campaign.type)
    RedisPredictiveCampaign.running_campaigns.should eq(["#{campaign.id}"])
  end
  
  it "should add the same running campaign once to the set" do
    account = create(:account)
    campaign = create(:predictive, name: "test123", account: account)
    RedisPredictiveCampaign.add(campaign.id, campaign.type)
    RedisPredictiveCampaign.add(campaign.id, campaign.type)
    RedisPredictiveCampaign.running_campaigns.should eq(["#{campaign.id}"])
  end
  
  
  it "should add multiple to running campaigns" do
    account = create(:account)
    campaign1 = create(:predictive, name: "test123", account: account)
    campaign2 = create(:predictive, name: "test456", account: account)
    RedisPredictiveCampaign.add(campaign1.id, campaign1.type)
    RedisPredictiveCampaign.add(campaign2.id, campaign2.type)    
    RedisPredictiveCampaign.running_campaigns.should eq(["#{campaign1.id}", "#{campaign2.id}"])
  end
  
  
end
