require "spec_helper"

describe ClientController do

  describe "when not logged in" do
    it "redirects to the login page" do
      get "/client"
      response.should redirect_to "/client/login"
    end
  end


  describe "when logged in" do
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
  end
end
