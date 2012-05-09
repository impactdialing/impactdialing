require "spec_helper"

describe CallsController do
  
  describe "incoming call" do
    
    it "should abandon call if answered by human and caller not available" do
      campaign = Factory(:preview)
      voter = Factory(:voter, campaign: campaign)
      call_attempt = Factory(:call_attempt, voter: voter, campaign: campaign)
      call = Factory(:call, call_sid: "123456", call_attempt: call_attempt, all_states: "")      
      post :flow, CallSid:  "123456", answered_by: "human", event: 'incoming_call'      
    end
  end
end