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
      RedisCampaign.should_receive(:add_running_predictive_campaign).with(caller.campaign_id, caller.campaign.type)
      RedisCaller.should_receive(:add_caller).with(caller.campaign.id, caller_session.id)
      RedisCallNotification.should_receive(:caller_connected).with(caller_session.id)      
      post :start_calling, caller_id: caller.id, session_key: caller_identity.session_key, CallSid: "abc"      
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Your account has insufficent funds</Say><Hangup/></Response>")
    end
  end
  
  describe "call voter" do
    it "should call voter" do
      campaign =  Factory(:predictive)
      caller = Factory(:caller, campaign: campaign, account: Factory(:account))
      caller_identity = Factory(:caller_identity)
      caller_session = Factory(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT, caller: caller)
      voter = Factory(:voter,campaign: campaign)
      Resque.should_receive(:enqueue).with(CallerPusherJob, caller_session.id, "publish_calling_voter")   
      Resque.should_receive(:enqueue).with(PreviewPowerDialJob, caller_session.id, voter.id.to_s)    
      post :call_voter, id: caller.id, voter_id: voter.id, session_id: caller_session.id
    end
  end
 
end
