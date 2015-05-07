require 'rails_helper'

describe Client::CampaignsController, type: :controller do
  let(:question) { build(:question) }
  let(:script) { create(:script) }
  let(:campaign) { build(:campaign) }

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

    # archived, restore, can_change_script
    describe 'the #archived' do
      it 'allows admin access' do
        get(:archived, html_params)
      end
    end

    describe 'the #restore' do
      it 'allows admin access' do
        get(:restore, json_params)
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

    after do
      expect(response.status).to eq 200
    end

  end
end
