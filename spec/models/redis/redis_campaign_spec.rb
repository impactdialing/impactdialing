require "spec_helper"

describe RedisCampaign do
  
  it "should load campaign info into a spec" do
    account = Factory(:account)
    campaign = Factory(:predictive, name: "test123", account: account)
    RedisCampaign.load_campaign(campaign.id, campaign)
    RedisCampaign.read_campaign(campaign.id).should eq({"acceptable_abandon_rate"=>"", "account_id"=>"#{account.id}", "active"=>"true", "amd_turn_off"=>"", "answer_detection_timeout"=>"20", "answering_machine_detect"=>"", "caller_id"=>"1234567890", "callin_number"=>"4157020991", "calls_in_progress"=>"false", "campaign_id"=>"#{campaign.campaign_id}", "created_at"=>"#{campaign.created_at}", "end_time"=>"#{campaign.end_time}", "group_id"=>"", "id"=>"#{campaign.id}", "name"=>"test123", "ratio_override"=>"0.0", "recording_id"=>"", "recycle_rate"=>"1", "robo"=>"false", "script_id"=>"1", "start_time"=>"#{campaign.start_time}", "time_zone"=>"Pacific Time (US & Canada)", "type"=>"Predictive", "updated_at"=>"#{campaign.updated_at}", "use_answering"=>"true", "use_recordings"=>"false", "voicemail_script_id"=>""})
  end
  
  it "should add to running campaigns" do
    account = Factory(:account)
    campaign = Factory(:predictive, name: "test123", account: account)
    RedisCampaign.add_running_campaign(campaign.id, campaign.type)
    RedisCampaign.running_campaigns.should eq(["{:campaign_id=>#{campaign.id}, :type=>\"Predictive\"}"])
  end
  
  it "should add the same running campaign once to the set" do
    account = Factory(:account)
    campaign = Factory(:predictive, name: "test123", account: account)
    RedisCampaign.add_running_campaign(campaign.id, campaign.type)
    RedisCampaign.add_running_campaign(campaign.id, campaign.type)
    RedisCampaign.running_campaigns.should eq(["{:campaign_id=>#{campaign.id}, :type=>\"Predictive\"}"])
  end
  
  
  it "should add multiple to running campaigns" do
    account = Factory(:account)
    campaign1 = Factory(:predictive, name: "test123", account: account)
    campaign2 = Factory(:preview, name: "test456", account: account)
    RedisCampaign.add_running_campaign(campaign1.id, campaign1.type)
    RedisCampaign.add_running_campaign(campaign2.id, campaign2.type)    
    RedisCampaign.running_campaigns.should eq(["{:campaign_id=>#{campaign2.id}, :type=>\"Preview\"}" , "{:campaign_id=>#{campaign1.id}, :type=>\"Predictive\"}"])
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
