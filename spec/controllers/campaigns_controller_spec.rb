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
    let(:admin) { create(:user, {account: campaign.account}) }

    before do
      allow(controller).to receive(:current_user) { admin }
    end

    # after do
    #   expect(response.status).to eq 200
    # end

    describe 'functionality of controllers' do
      let(:show_redirect){ edit_client_campaign_path(campaign) }
    # let(:) others will follow this format...

      it_behaves_like 'the admin CRUD methods'
    end

    describe 'the #archived' do
      it 'renders the "archived" template' do
        get(:archived, html_params)
        expect(response).to render_template "archived"
      end
    end
# how to best write -it- statements: to describe the methods assuming access?
# and then write the supervisor -it- as "disallows and redirects"?

    describe 'the #restore' do
      let(:current_template) { { message: "Campaign restored" }.to_json }
      it 'restores that campaign' do
        patch(:restore, json_params)
        expect(response.body).to eq current_template
      end
    end

    describe 'the #can_change_script' do
      let(:current_template) { { message: true, script_id: campaign.script_id }.to_json }
      it 'allows admin access' do
        patch(:can_change_script, json_params)
        expect(response.body).to eq current_template
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

    describe 'functionality of controllers' do
      it_behaves_like 'the supervisor CRUD methods'
    end

    describe 'the #archived' do
      it 'disallows supervisor access' do
        get(:archived, html_params)
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
