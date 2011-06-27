require "spec_helper"

describe ClientController do

  describe "when not logged in" do
    it "redirects to the login page" do
      get "/client"
      response.should redirect_to "/client/login"
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

    it "lists all manual campaigns" do
      robo_campaign = Factory(:campaign, :user => user, :robo => true)
      manual_campaign = Factory(:campaign, :user => user, :robo => false)
      get :campaigns
      assigns(:campaigns).should == [manual_campaign]
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
