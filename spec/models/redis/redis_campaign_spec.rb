require "spec_helper"

describe RedisCampaign do
  
  it "should load campaign info into a spec" do
    account = Factory(:account)
    script = Factory(:script)
    campaign = Factory(:predictive, name: "test123", account: account, script: script)
    RedisCampaign.load_campaign(campaign.id, campaign)
    RedisCampaign.read_campaign(campaign.id).should eq({"id"=>"#{campaign.id}", "campaign_id"=>"", "name"=>"#{campaign.name}", "account_id"=>"1", "script_id"=>"#{script.id}", "active"=>"true", "created_at"=>"#{campaign.created_at}", "updated_at"=>"#{campaign.updated_at}", "caller_id"=>"1234567890", "type"=>"Predictive", "recording_id"=>"", "use_recordings"=>"false", "calls_in_progress"=>"false", "recycle_rate"=>"1", "answering_machine_detect"=>"", "start_time"=>"#{campaign.start_time}", "end_time"=>"#{campaign.end_time}", "time_zone"=>"Pacific Time (US & Canada)", "acceptable_abandon_rate"=>""})
  end
  
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
