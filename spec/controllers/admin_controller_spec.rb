require "spec_helper"

describe AdminController do
  render_views

  context 'when logged in' do
    before(:each) do
      @controller.should_receive(:authenticate).and_return(true)
      request.env['HTTP_REFERER'] = 'http://referer'
    end

    [true, false].each do |old_activated|
      it "toggles paid to #{old_activated}" do
        account = Factory(:account, :activated => old_activated)
        post :toggle_activated, :id => account.id
        account.reload.activated.should == !old_activated
        response.should redirect_to(:back)
      end
    end

    it "generates an admin report" do
      get :report
      response.should be_ok
    end

    it "reports state of the app" do
      account = Factory(:account)
      campaign = Factory(:campaign, :account => account)
      Factory(:user, :account => account)
      caller_session = Factory(:caller_session, :campaign => campaign, :on_call => true, :available_for_call => true)
      call_attempt = Factory(:call_attempt, :caller_session => caller_session, :call_end => nil)
      get :state
      response.should be_ok
    end
  end
end
