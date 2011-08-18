require "spec_helper"

describe CallerController do
  describe 'index' do
    it "doesn't list deleted campaigns" do
      caller = Factory(:caller)
      caller.campaigns << Factory(:campaign, :active => false)
      caller.campaigns << Factory(:campaign, :active => true)
      caller.save!
      login_as(caller)
      get :index
      assigns(:campaigns).should have(1).thing
      assigns(:campaigns)[0].should be_active
    end
  end

  describe "preview dial" do

    it "connects to twilio before making a call" do
      session_key = "sdklsjfg923784"
      caller = Factory(:caller)
      login_as(caller)
      session = Factory(:caller_session, :caller=> caller, :session_key => session_key)
      CallerSession.stub(:find_by_session_key).with(session_key).and_return(session)
      session.stub(:call)
      Twilio.should_receive(:connect).with(anything,anything)
      get :preview_dial, :key => session_key, :voter_id => Factory(:voter).id
    end


  end
end
