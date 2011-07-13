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

  end


end
