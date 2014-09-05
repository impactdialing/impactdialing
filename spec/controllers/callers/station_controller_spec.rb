require 'spec_helper'

describe Callers::StationController do
  describe '#show?campaign_id' do
    include FakeCallData

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
    context 'campaign_id is present' do
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