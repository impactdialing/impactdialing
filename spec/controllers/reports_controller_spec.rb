require "spec_helper"

describe ReportsController do

  context 'when logged in' do
    let(:user) { Factory(:user) }

    before(:each) do
      login_as user
    end

    it "lists all campaigns" do
      Factory(:campaign, :active => false)
      Factory(:campaign, :active => true)
      get :index
      assigns(:campaigns).should have(1).thing
      assigns(:campaigns)[0].should be_active
    end

    it "lists usage for a campaign" do
      campaign = Factory(:campaign, :active => true)
      get :usage, :campaign_id => campaign.id
      assigns(:campaign).should == campaign
      assigns(:minutes).should_not be_nil
    end

  end


end
