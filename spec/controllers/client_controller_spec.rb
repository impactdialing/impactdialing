require "spec_helper"

describe ClientController do
  describe 'campaign_new' do
    it "creates a new campaign & redirects to campaign view" do
      login_as Factory(:user)
      lambda {
        get :campaign_new
      }.should change(Campaign, :count).by(1)
      response.should redirect_to "/client/campaign_view/#{Campaign.last.id}"
    end
  end
end
