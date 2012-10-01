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
      caller = Factory(:caller, campaign: Factory(:predictive))
      caller_identity = Factory(:caller_identity)
      caller_session = Factory(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT)
      caller.should_receive(:create_caller_session).and_return(caller_session)
      RedisCampaign.should_receive(:add_running_predictive_campaign).with(caller.campaign_id, caller.campaign.type)
      RedisCaller.should_receive(:add_caller).with(caller.campaign.id, caller_session.id)
      RedisCallNotification.should_receive(:caller_connected(session.id)
      
      post :start_calling, caller_id: caller.id, session_key: caller_identity.session_key, CallSid: "abc"
      
    end
  end
 
end
