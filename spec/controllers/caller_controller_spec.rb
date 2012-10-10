require "spec_helper"

describe CallerController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }

  describe "preview dial" do
    let(:campaign) { Factory(:campaign, start_time: Time.now - 6.hours, end_time: Time.now + 6.hours) }

    before(:each) do
      @caller = Factory(:caller, :account => account)
      login_as(@caller)
    end

    it "logs out" do
      @caller = Factory(:caller, :account => account)
      login_as(@caller)
      post :logout
      session[:caller].should_not be
      response.should redirect_to(caller_login_path)
    end

  end  
  
  describe "start calling" do
    it "should start a new caller conference" do
      caller = Factory(:caller, campaign: Factory(:predictive), account: Factory(:account))
      caller_identity = Factory(:caller_identity)
      caller_session = Factory(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT, caller: caller)
      Caller.should_receive(:find).and_return(caller)
      caller.should_receive(:create_caller_session).and_return(caller_session)
      RedisPredictiveCampaign.should_receive(:add).with(caller.campaign_id, caller.campaign.type)
      # caller.should_receive(:enqueue_dial_flow).with(CampaignStatusJob, ["caller_connected", caller.campaign.id, nil, caller_session.id])       
      post :start_calling, caller_id: caller.id, session_key: caller_identity.session_key, CallSid: "abc"      
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Your account has insufficent funds</Say><Hangup/></Response>")
    end
  end
  
  describe "call voter" do
    it "should call voter" do
      campaign =  Factory(:predictive)
      caller = Factory(:caller, campaign: campaign, account: Factory(:account))
      caller_identity = Factory(:caller_identity)
      voter = Factory(:voter, campaign: campaign)
      caller_session = Factory(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT, caller: caller)
      Caller.should_receive(:find).and_return(caller)
      caller.should_receive(:calling_voter_preview_power)
      post :call_voter, id: caller.id, voter_id: voter.id, session_id: caller_session.id
    end
  end
 
end
