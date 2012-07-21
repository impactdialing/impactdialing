require "spec_helper"

describe ModeratorJob do
  
  it "should not push if monitor screen refreshed" do
    campaign = Factory(:campaign)
    ModeratorCampaign.new(campaign.id,10,2,3,3,2,10,120,140)    
    MonitorPubSub.should_not_receive(:new)
    ModeratorJob.perform(campaign.id, "incoming_call",Time.now) 
  end
  
  it "should  push if monitor screen refreshed after events" do
    campaign = Factory(:campaign)
    event_time = Time.now - 5.seconds
    ModeratorCampaign.new(campaign.id,10,2,3,3,2,10,120,140)    
    MonitorPubSub.should_not_receive(:new)
    ModeratorJob.perform(campaign.id, "incoming_call",event_time) 
  end
  
end