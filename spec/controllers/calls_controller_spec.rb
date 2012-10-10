require "spec_helper"

describe CallsController do
  
  describe "call ended" do
        
    it "should only render twiml if call connected" do
      call = Factory(:call, answered_by: "human", call_attempt: @call_attempt, state: 'initial', call_status: "completed")
      post :call_ended, CallStatus: "completed", id: call.id       
      RedisCall.should_not_receive(:push_to_not_answered_call_list)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end
    
    
  end
end