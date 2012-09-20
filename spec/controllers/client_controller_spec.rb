require "spec_helper"

describe ClientController do
  before(:each) do
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  describe "when not logged in" do
    it "creates a new user with the appropriate domain" do
      request.should_receive(:domain).and_return('domain.com')
      lambda {
        post :user_add, :user => { :email => 'email@example.com', :new_password => 'something' }, :tos => true
      }.should change(User, :count).by(1)
      User.last.account.domain_name.should == 'domain.com'
    end
  end

  context "when logged in" do
    let(:user) { Factory(:user) }

    before :each do
      login_as user
    end

    describe "and attempt to login yet again" do
      it "redirects to 'add new client'" do
        get "login"
        response.should redirect_to "/client/user_add"
      end
    end
  end
end
