require 'rails_helper'

describe Callers::StationController do
  include FakeCallData

  before do
    admin       = create(:user)
    other_admin = create(:user)
    @account    = admin.account
    @campaign   = create_campaign_with_script(:bare_power, @account).last
    @caller     = create(:caller, {campaign: @campaign, account: @account})
  end

  describe '#login' do
    context 'Caller#campaign_id is blank' do
      before do
        @caller.update_attributes!(campaign_id: nil)
        post :login, username: @caller.username, password: @caller.password
      end

      it 're-renders login form' do
        expect(response).to render_template 'callers/station/login'
      end
    end
    context 'Caller#campaign is archived' do
      before do
        campaign = @caller.campaign
        campaign.active = false
        campaign.save!
        post :login, username: @caller.username, password: @caller.password
      end

      it 're-renders login form' do
        expect(response).to render_template 'callers/station/login'
      end
    end
  end

  describe '#logout' do
    before do
      post :login, username: @caller.username, password: @caller.password
      expect(response.headers['Location']).to match /#{callveyor_path}/
    end

    it 'clears session[:caller]' do
      post :logout
      expect(session[:caller]).to be_nil
    end

    it 'redirects to /login' do
      post :logout
      expect(response).to redirect_to callveyor_login_path
    end
  end
  
  describe '#show?campaign_id' do
    before do
      admin                = create(:user)
      other_admin          = create(:user)
      @account             = admin.account
      @other_account       = other_admin.account
      @campaign            = create_campaign_with_script(:bare_power, @account).last
      @assignable_campaign = create_campaign_with_script(:bare_power, @account).last
      @other_campaign      = create_campaign_with_script(:bare_power, @other_account).last
      @caller              = create(:caller, {campaign: @campaign, account: @account})
    end

    context 'Caller#campaign_id is nil (possible if caller session still active after campaign archive)' do
      before do
        login_as(@caller)
        @caller.update_attributes!(campaign_id: nil)
      end

      shared_examples 'whenever Caller#campaign_id is nil' do
        it 'clears session[:caller]' do
          self.send(verb, action)
          expect(session[:caller]).to be_nil
        end
        it 'redirects to login page' do
          self.send(verb, action)
          expect(response).to redirect_to callveyor_login_path
        end
      end

      context '#show' do
        let(:verb){ :get }
        let(:action){ :show }
        it_behaves_like 'whenever Caller#campaign_id is nil'
      end

      context '#script' do
        let(:verb){ :get }
        let(:action){ :script }
        it_behaves_like 'whenever Caller#campaign_id is nil'
      end

      context '#create' do
        let(:verb){ :post }
        let(:action){ :create }
        it_behaves_like 'whenever Caller#campaign_id is nil'
      end
    end
    
    context 'campaign_id is present in params' do
      before do
        login_as(@caller)
      end
      context 'campaign_id identifies Campaign not associated with @caller.account_id' do
        let(:params) do
          {campaign_id: @other_campaign.id}
        end
        it 'does not assign @caller to other campaign' do
          get :show, params
          @caller.reload
          expect(@caller.campaign_id).to eq @campaign.id
        end
        it 'renders callers/station/show.html.erb' do
          get :show, params
          expect(response).to render_template 'callers/station/show'
        end
      end

      context 'campaign_id identifies Campaign that is associated with @caller.account_id' do
        let(:params) do
          {campaign_id: @assignable_campaign.id}
        end
        it 'assigns @caller to Campaign identified by campaign_id' do
          get :show, params
          @caller.reload
          expect(@caller.campaign_id).to eq @assignable_campaign.id
        end

        it 'renders callers/station/show.html.erb' do
          get :show, params
          expect(response).to render_template 'callers/station/show'
        end
      end
    end
  end
end