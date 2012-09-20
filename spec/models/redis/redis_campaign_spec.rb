require "spec_helper"

describe RedisCampaign do
  
  
  it "should add to running campaigns" do
    account = Factory(:account)
    campaign = Factory(:predictive, name: "test123", account: account)
    RedisCampaign.add_running_predictive_campaign(campaign.id, campaign.type)
    RedisCampaign.running_campaigns.should eq(["#{campaign.id}"])
  end
  
  it "should add the same running campaign once to the set" do
    account = Factory(:account)
    campaign = Factory(:predictive, name: "test123", account: account)
    RedisCampaign.add_running_predictive_campaign(campaign.id, campaign.type)
    RedisCampaign.add_running_predictive_campaign(campaign.id, campaign.type)
    RedisCampaign.running_campaigns.should eq(["#{campaign.id}"])
  end
  
  
  it "should add multiple to running campaigns" do
    account = Factory(:account)
    campaign1 = Factory(:predictive, name: "test123", account: account)
    campaign2 = Factory(:predictive, name: "test456", account: account)
    RedisCampaign.add_running_predictive_campaign(campaign1.id, campaign1.type)
    RedisCampaign.add_running_predictive_campaign(campaign2.id, campaign2.type)    
    RedisCampaign.running_campaigns.should eq(["#{campaign1.id}", "#{campaign2.id}"])
  end
  
  it "should return call status as voicemail if user recording turned on" do
    account = Factory(:account)
    campaign = Factory(:predictive, name: "test123", account: account, use_recordings: true)
    RedisCampaign.load_campaign(campaign.id, campaign)
    RedisCampaign.call_status_use_recordings(campaign.id).should eq(CallAttempt::Status::VOICEMAIL)
  end
  
  it "should return call status as hangup if user recording turned off" do
    account = Factory(:account)
    campaign = Factory(:predictive, name: "test123", account: account, use_recordings: false)
    RedisCampaign.load_campaign(campaign.id, campaign)
    RedisCampaign.call_status_use_recordings(campaign.id).should eq(CallAttempt::Status::HANGUP)
  end
  
end
