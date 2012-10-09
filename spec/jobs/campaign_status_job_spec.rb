require "spec_helper"

describe CampaignStatusJob do
  before(:each) do
    @campaign = Factory(:campaign)
    @call_attempt = Factory(:call_attempt)
    @caller_session = Factory(:caller_session)
    @job = CampaignStatusJob.new
  end
  
  it "dialing should add call to ringing" do
    RedisCampaignCall.should_receive(:add_to_ringing).with(@campaign.id, @call_attempt.id)     
    @job.dialing(@campaign.id, @call_attempt.id, @caller_session.id)
  end
  
   it "failed should move rinnging to completed" do
     RedisCampaignCall.should_receive(:move_ringing_to_completed).with(@campaign.id, @call_attempt.id)     
     @job.failed(@campaign.id, @call_attempt.id, @caller_session.id)     
   end
   
   it "send events for connected" do
     RedisCampaignCall.should_receive(:move_ringing_to_inprogress).with(@campaign.id, @call_attempt.id)     
     RedisCaller.should_receive(:move_on_hold_to_on_call).with(@campaign.id, @caller_session.id)
     @job.should_receive(:enqueue_monitor_caller_flow).with(MonitorCallerJob, [@campaign.id, @caller_session.id, "On call", "update"])
     @job.connected(@campaign.id, @call_attempt.id, @caller_session.id)
   end
   
   it "send events for disconnected" do
     RedisCampaignCall.should_receive(:move_inprogress_to_wrapup).with(@campaign.id, @call_attempt.id)     
     RedisCaller.should_receive(:move_on_call_to_on_wrapup).with(@campaign.id, @caller_session.id)
     @job.should_receive(:enqueue_monitor_caller_flow).with(MonitorCallerJob, [@campaign.id, @caller_session.id, "Wrap up", "update"])
     @job.disconnected(@campaign.id, @call_attempt.id, @caller_session.id)
   end
   
   it "should send events for disconnected" do
     RedisCampaignCall.should_receive(:move_ringing_to_abandoned).with(@campaign.id, @call_attempt.id); 
     @job.abandoned(@campaign.id, @call_attempt.id, @caller_session.id)
   end
   
   it "should send events answered machine" do
     RedisCampaignCall.should_receive(:move_ringing_to_completed).with(@campaign.id, @call_attempt.id);
     @job.answered_machine(@campaign.id, @call_attempt.id, @caller_session.id)
   end
   
   it "send events for wrapped up" do
     RedisCampaignCall.should_receive(:move_wrapup_to_completed).with(@campaign.id, @call_attempt.id)     
     @job.should_receive(:enqueue_monitor_caller_flow).with(MonitorCallerJob, [@campaign.id, @caller_session.id, "On hold", "update"])
     @job.wrapped_up(@campaign.id, @call_attempt.id, @caller_session.id)
   end
   
   it "should send events for on hold" do
     RedisCaller.should_receive(:move_to_on_hold).with(@campaign.id, @caller_session.id)
     @job.on_hold(@campaign.id, @call_attempt.id, @caller_session.id)     
   end
   
   it "should send events for caller_connected" do
     RedisCaller.should_receive(:add_caller).with(@campaign.id, @caller_session.id)
     @job.should_receive(:enqueue_monitor_caller_flow).with(MonitorCallerJob, [@campaign.id, @caller_session.id, "caller_connected", "new"])
     @job.caller_connected(@campaign.id, @call_attempt.id, @caller_session.id)     
   end

   it "should send events for caller_disconnected" do
     RedisCaller.should_receive(:disconnect_caller).with(@campaign.id, @caller_session.id)
     @job.should_receive(:enqueue_monitor_caller_flow).with(MonitorCallerJob, [@campaign.id, @caller_session.id, "caller_disconnected", "delete"])
     @job.caller_disconnected(@campaign.id, @call_attempt.id, @caller_session.id)     
   end
   
  
end