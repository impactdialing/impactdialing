require "spec_helper"

describe AdminController do
  context 'when logged in' do
    before(:each) do
      @controller.should_receive(:authenticate).and_return(true)
      request.env['HTTP_REFERER'] = 'http://referer'
    end

    [true, false].each do |old_paid|
      it "toggles paid to #{old_paid}" do
        user = Factory(:user, :account => Factory(:account, :paid => old_paid))
        post :toggle_paid, :id => user.id
        user.account.reload.paid.should == !old_paid
        response.should redirect_to(:back)
      end
    end

    it "generates an admin report" do
      get :report
      response.should be_ok
    end
  end
end
