require "spec_helper"

describe AdminController do
  render_views

  context 'when logged in' do
    before(:each) do
      @controller.should_receive(:authenticate).and_return(true)
      request.env['HTTP_REFERER'] = 'http://referer'
    end

    [true, false].each do |old_paid|
      it "toggles paid to #{old_paid}" do
        account = Factory(:account, :paid => old_paid)
        post :toggle_paid, :id => account.id
        account.reload.paid.should == !old_paid
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
