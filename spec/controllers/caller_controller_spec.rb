require "spec_helper"

describe CallerController do
  let(:account) { create(:account) }
  let(:user) { create(:user, :account => account) }

  describe "preview dial" do
    let(:campaign) { create(:campaign, start_time: Time.now - 6.hours, end_time: Time.now + 6.hours) }

    before(:each) do
      @caller = create(:caller, :account => account)
      login_as(@caller)
    end

    it "logs out" do
      @caller = create(:caller, :account => account)
      login_as(@caller)
      post :logout
      session[:caller].should_not be
      response.should redirect_to(caller_login_path)
    end

  end  
  
  describe "start calling" do
    it "should start a new caller conference" do
      account = create(:account)
      campaign = create(:predictive, account: account)      
      caller = create(:caller, campaign: campaign, account: account)
      caller_identity = create(:caller_identity)
      caller_session = create(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT, caller: caller, campaign: campaign)
      Caller.should_receive(:find).and_return(caller)
      caller.should_receive(:create_caller_session).and_return(caller_session)
      RedisPredictiveCampaign.should_receive(:add).with(caller.campaign_id, caller.campaign.type)
      post :start_calling, caller_id: caller.id, session_key: caller_identity.session_key, CallSid: "abc"      
      response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/pause?session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
    end
  end
  
  describe "call voter" do
    it "should call voter" do
      account = create(:account)
      campaign =  create(:predictive, account: account)
      caller = create(:caller, campaign: campaign, account: account)
      caller_identity = create(:caller_identity)
      voter = create(:voter, campaign: campaign)
      caller_session = create(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT, caller: caller)
      Caller.should_receive(:find).and_return(caller)
      caller.should_receive(:calling_voter_preview_power)
      post :call_voter, id: caller.id, voter_id: voter.id, session_id: caller_session.id
    end
  end
 
end
