require 'rails_helper'

# @@reassign_to_campaign, @@usage, @@call_details,
# archived, restore, type_name

describe Client::CallersController, type: :controller do
  let(:caller) { create(:caller) }

  let(:json_params) do
    {
      :id => caller.id,
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

  # reassign_campaign, call_details, usage - what to expect?


  context 'when user is admin' do
    before do
      allow(controller).to receive(:current_user) { create(:user) }
    end

    describe 'the #archived' do
      it 'allows admin access' do
        get(:archived, html_params)
        expect(response.status).to eq 200
      end
    end

    describe 'the #restore' do
      it 'allows admin access' do
        get(:restore, html_params)
        expect(response.status).to eq 200
      end
    end

    describe 'the #call_details' do
      it 'allows admin access' do
        get(:call_details, html_params)
        expect(response.status).to eq 200
      end
    end

    describe 'the #usage' do
      it 'allows admin access' do
        get(:usage, html_params)
        expect(response.status).to eq 200
      end
    end

    describe 'the #reassign_to_campaign' do
      it 'allows admin access' do
        get(:reassign_to_campaign, html_params)
        expect(response.status).to eq 200
      end
    end
  end

  context 'when user is supervisor' do
    let(:supervisor){ create(:user, {role: 'supervisor', account: caller.account}) }
    before do
      allow(controller).to receive(:current_user) do
        supervisor
      end
    end

    describe 'the #archived' do
      it 'disallows supervisor access' do
        get(:archived, html_params)
        expect(response).to redirect_to root_url
      end
    end

    describe 'the #restore' do
      it 'disallows supervisor access' do
        get(:restore, html_params)
        expect(response).to redirect_to root_url
      end
    end

    describe 'the #call_details' do
      it 'allows supervisor access' do
        get(:call_details, html_params)
        expect(response.status).to eq 200
      end
    end

    describe 'the #usage' do
      it 'allows supervisor access' do
        get(:usage, html_params)
        expect(response.status).to eq 200
      end
    end

    describe 'the #reassign_to_campaign' do
      it 'allows supervisor access' do
        get(:reassign_to_campaign, html_params)
        expect(response.status).to eq 200
      end
    end
  end
end
