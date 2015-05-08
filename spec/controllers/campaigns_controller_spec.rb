require 'rails_helper'

describe Client::CampaignsController, type: :controller do
  let(:question) { create(:question) }
  let(:script) { create(:script) }
  let(:campaign) { create(:campaign) }

  let(:json_params) do
    {
      :id => campaign.id,
      :format => :json
    }
  end

  let(:html_params) do
    json_params.merge({:format => :html})
  end

  before do
    allow(controller).to receive(:check_login) { true }
    allow(controller).to receive(:check_tos_accepted) { true }
  end

  context 'when user is admin' do
    before do
      allow(controller).to receive(:current_user) { create(:user) }
    end

    after do
      expect(response.status).to eq 200
    end

    describe 'the #archived' do
      it 'allows admin access' do
        get(:archived, html_params)
      end
    end

    describe 'the #restore' do
      it 'allows admin access' do
        patch(:restore, json_params)
      end
    end

    describe 'the #can_change_script' do
      it 'allows admin access' do
        patch(:can_change_script, json_params)
      end
    end
  end

  context 'when user is supervisor' do
    let(:supervisor){ create(:user, {role: 'supervisor', account: campaign.account}) }
    before do
      allow(controller).to receive(:current_user) do
        supervisor
      end
    end

    describe 'the #archived' do
      it 'disallows supervisor access' do
        get(:archived, html_params)
        # expect(response.body).to include I18n.t(:admin_access)
        expect(response).to redirect_to root_url
      end
    end

    describe 'the #restore' do
      it 'disallows supervisor access' do
        get(:restore, json_params)
        expect(response.body).to include I18n.t(:admin_access)
      end
    end

    describe 'the #can_change_script' do
      it 'disallows supervisor access' do
        get(:can_change_script, json_params)
        expect(response.body).to include I18n.t(:admin_access)
      end
    end
  end
end
