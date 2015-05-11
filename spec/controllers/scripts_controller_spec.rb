require 'rails_helper'

describe Client::ScriptsController, type: :controller do
  let(:question) { build(:question) }
  let(:script) { create(:script) }

  let(:json_params) do
    {
      :id => script.id,
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

    describe 'the #questions_answered' do
      it 'allows admin access' do
        get(:questions_answered, json_params)
      end
    end

    describe 'the #possible_responses_answered' do
      it 'allows admin access' do
        get(:possible_responses_answered, json_params)
      end
    end

    describe 'the #archived' do
      it 'allows admin access' do
        get(:archived, html_params)
      end
    end

    describe 'the #restore' do
      it 'allows admin access' do
        patch(:restore, html_params)
      end
    end
  end

  context 'when user is supervisor' do
    let(:supervisor){ create(:user, {role: 'supervisor', account: script.account}) }
    before do
      allow(controller).to receive(:current_user) do
        supervisor
      end
    end

    describe 'the #questions_answered' do
      it 'disallows supervisor access' do
        get(:questions_answered, json_params)
        expect(response.body).to include I18n.t(:admin_access)
      end
    end

    describe 'the #possible_responses_answered' do
      it 'disallows supervisor access' do
        get(:possible_responses_answered, json_params)
        expect(response.body).to include I18n.t(:admin_access)
      end
    end

    describe '#archived' do
      it 'disallows supervisor access' do
        patch(:archived, html_params)
        expect(response).to redirect_to root_url
      end
    end

    describe '#restore' do
      it 'disallows supervisor access' do
        patch(:restore, html_params)
        expect(response).to redirect_to root_url
      end
    end
  end
end
