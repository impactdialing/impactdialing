require "spec_helper"

describe BlockedNumbersController, :type => :controller do
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
      expect(assigns(:blocked_numbers)).to eq(blocked_numbers)
    end

    it "loads all active campaigns" do
      active_user_campaigns = 3.times.map{ create(:preview, :account => account, :active => true) }
      another_users_active_campaign = create(:preview, :account => create(:account), :active => true)
      inactive_user_campaign = create(:preview, :account => account, :active => false)
      get :index
      expect(assigns(:campaigns)).to eq(active_user_campaigns)
    end
  end

  describe 'create' do
    it "creates a new system blocked number" do
      expect {
        post :create, :blocked_number => {:number => '1234567890', :campaign_id => nil}
      }.to change { account.reload.blocked_numbers.size }.by(1)
      expect(account.blocked_numbers.last.number).to eq('1234567890')
      expect(account.blocked_numbers.last.campaign_id).to eq(nil)
      expect(response).to redirect_to(:back)
      expect(flash[:notice]).to include("Do Not Call number added")
    end

    it "creates a new campaign-specific blocked number" do
      expect {
        post :create, :blocked_number => {:number => '1234567890', :campaign_id => 1}
      }.to change { account.reload.blocked_numbers.size }.by(1)
      expect(account.blocked_numbers.last.number).to eq('1234567890')
      expect(account.blocked_numbers.last.campaign_id).to eq(1)
      expect(response).to redirect_to(:back)
      expect(flash[:notice]).to include("Do Not Call number added")
    end

    it "doesn't create anything if there's a validation error" do
      expect {
        post :create, :blocked_number => { :number => '123456789' }
      }.not_to change { account.reload.blocked_numbers.size }
      expect(flash[:error]).to include("Number is too short (minimum is 10 characters)")
      expect(response).to redirect_to(:back)
    end
  end

  describe 'destroy' do
    it "destroys an existing blocked number" do
      blocked_number = create(:blocked_number, :account => account)
      delete :destroy, :id => blocked_number.id
      expect(BlockedNumber.find_by_id(blocked_number.id)).not_to be
      expect(response).to redirect_to(:back)
    end
  end

end
