require "spec_helper"

describe CallsController do

  describe "call ended" do

    it "should only render twiml if call connected" do
      caller                      = create(:caller)
      call                        = create(:call, answered_by: "human", state: 'initial', call_status: "completed")
      caller_session              = create(:webui_caller_session, {caller: caller})
      call_attempt                = call.call_attempt
      call_attempt.caller_session = caller_session
      call_attempt.caller         = caller
      call_attempt.save!

      post :call_ended, CallStatus: "completed", id: call.id
      RedisCallFlow.should_not_receive(:push_to_not_answered_call_list)
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end


  end
end