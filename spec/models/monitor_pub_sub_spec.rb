require 'spec_helper'

describe MonitorPubSub do
  
  it "should push to monitor screen" do
    pub_sub = MonitorPubSub.new
    campaign = Factory(:predictive)    
    moderator_event = mock(ModeratorEvent)
    ModeratorEvent.should_receive(:new).and_return(moderator_event)
    moderator_event.should_receive(:send)
    moderator = Factory(:moderator)
    Moderator.should_receive(:active_moderators).and_return([moderator])
    ModeratorCampaign.new(campaign.id, 5,2,1,1,2,5,123,234)
    channel = mock
    Pusher.should_receive(:[]).with(moderator.session).and_return(channel)
    channel.should_receive(:trigger_async)
    pub_sub.push_to_monitor_screen(campaign.id, "incoming_call", Time.now)
  end
  
end
