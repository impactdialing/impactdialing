require "spec_helper"

describe ClientController do

  describe "when not logged in" do
    it "redirects to the login page" do
      get "/client"
      response.should redirect_to "/client/login"
    end

    it "creates a new user with the appropriate domain" do
      request.stub!(:domain).and_return('domain.com')
      lambda {
        post :user_add, :user => { :email => 'email@example.com', :new_password => 'something' }, :tos => true
      }.should change(User, :count).by(1)
      User.last.domain.should == 'domain.com'
    end
  end

  context "when logged in" do
    before :each do
      login_as Factory(:user)
    end

    describe "and attempt to login yet again" do
      it "redirects to 'add new client'" do
        get "login"
        response.should redirect_to "/client/user_add"
      end
    end

    describe 'new campaign' do
      it "creates a new campaign & redirects to campaign view" do
        lambda {
          get :campaign_new
        }.should change(Campaign, :count).by(1)
        response.should redirect_to "/client/campaign_view/#{Campaign.last.id}"
      end

      it "defaults the campaign's mode to predictive type" do
        get :campaign_new
        Campaign.last.predective_type.should == 'algorithm1'
      end
    end

    describe 'callers' do
      integrate_views
      it "shows" do
        get :callers
        response.code.should == '200'
      end
    end
  end
end
