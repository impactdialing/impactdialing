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
 
end
