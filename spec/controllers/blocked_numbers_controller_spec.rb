require "spec_helper"

describe BlockedNumbersController do
  let(:account) { create(:account) }
  let(:user) { create(:user, :account => account) }
  before(:each) do
    login_as(user)
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  describe 'index' do
    it "loads all blocked numbers" do
      blocked_numbers = 3.times.map{ create(:blocked_number, :account => account) }
      another_users_blocked_number = create(:blocked_number, :account => create(:account))
      get :index
      assigns(:blocked_numbers).should == blocked_numbers
    end

    it "loads all active campaigns" do
      active_user_campaigns = 3.times.map{ create(:preview, :account => account, :active => true) }
      another_users_active_campaign = create(:preview, :account => create(:account), :active => true)
      inactive_user_campaign = create(:preview, :account => account, :active => false)
      get :index
      assigns(:campaigns).should == active_user_campaigns
    end
  end

  describe 'create' do
    it "creates a new system blocked number" do
      lambda {
        post :create, :blocked_number => {:number => '1234567890', :campaign_id => nil}
      }.should change { account.reload.blocked_numbers.size }.by(1)
      account.blocked_numbers.last.number.should == '1234567890'
      account.blocked_numbers.last.campaign_id.should == nil
      response.should redirect_to(:back)
      flash[:notice].should include("Do Not Call number added")
    end

    it "creates a new campaign-specific blocked number" do
      lambda {
        post :create, :blocked_number => {:number => '1234567890', :campaign_id => 1}
      }.should change { account.reload.blocked_numbers.size }.by(1)
      account.blocked_numbers.last.number.should == '1234567890'
      account.blocked_numbers.last.campaign_id.should == 1
      response.should redirect_to(:back)
      flash[:notice].should include("Do Not Call number added")
    end

    it "doesn't create anything if there's a validation error" do
      lambda {
        post :create, :blocked_number => { :number => '123456789' }
      }.should_not change { account.reload.blocked_numbers.size }
      flash[:error].should include("Number is too short (minimum is 10 characters)")
      response.should redirect_to(:back)
    end
  end

  describe 'destroy' do
    it "destroys an existing blocked number" do
      blocked_number = create(:blocked_number, :account => account)
      delete :destroy, :id => blocked_number.id
      BlockedNumber.find_by_id(blocked_number.id).should_not be
      response.should redirect_to(:back)
    end
  end

end
