require "spec_helper"

describe MonitorJob do
  
  it "should not push if monitor screen refreshed" do
    campaign = Factory(:predictive)
    MonitorCampaign.new(campaign.id,10,2,3,3,2,10,120,140)    
    MonitorPubSub.should_not_receive(:new)
    MonitorJob.perform(campaign.id, "incoming_call",Time.now) 
  end
  
  it "should  push if monitor screen refreshed after events" do
    campaign = Factory(:predictive)
    event_time = Time.now - 5.seconds
    MonitorCampaign.new(campaign.id,10,2,3,3,2,10,120,140)    
    MonitorPubSub.should_not_receive(:new)
    MonitorJob.perform(campaign.id, "incoming_call",event_time) 
  end
  
end