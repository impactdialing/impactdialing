require 'rails_helper'

describe Client::CallersController, :type => :controller do
  let(:account) {create(:account, api_key: 'abc123')}
  before(:each) { @user = create(:user, account: account) }

  context 'users' do
    before(:each) do
      login_as @user
    end

    def type_name
      'caller'
    end

    it "lists callers" do
      get :index
      expect(response.code).to eq('200')
    end

    it "doesn't list deleted campaigns, in the dropdown list" do
      c1 = create(:preview, :active => false, :account => @user.account)
      c2 = create(:predictive, :active => true, :account => @user.account)
      get :new
      expect(assigns(:campaigns)).to have(1).thing
      expect(assigns(:campaigns)[0]).to be_active
    end

    it "should create a phones only caller" do
      name     = "name"
      campaign = create(:campaign, account: account)
      post :create, :caller => {:name => name, :is_phones_only => true, :campaign_id => campaign.id}
      caller = Caller.find_by_name(name)
      expect(caller).not_to be_nil
      expect(caller.is_phones_only).to be_truthy
    end

    it "should create a phones only caller" do
      username = "username"
      post :create, :caller => {:username => username, :is_phones_only => false, :campaign_id => create(:campaign, account: account).id}
      caller = Caller.find_by_username(username)
      expect(caller).not_to be_nil
      expect(caller.is_phones_only).to be_falsey
    end

    it 'should not create a caller whose campaign.account_id is different from the callers' do
      campaign_2 = create(:campaign)
      post :create, :caller => {:username => 'bob', :campaign_id => campaign_2.id}
      caller = Caller.find_by_username('bob')
      expect(caller).to be_nil
    end

    it 'creates a caller w/ valid params' do
      campaign = create(:power, account: account)
      caller_params = {
        caller: {
          username: 'bob',
          campaign_id: campaign.id,
          password: 'secret'
        }
      }
      post :create, caller_params
      created_caller = Caller.last
      expect(created_caller.username).to eq caller_params[:caller][:username]
      expect(created_caller.campaign).to eq campaign
      expect(created_caller.password).to eq caller_params[:caller][:password]
    end

    describe "call details report" do

      let(:script) { create(:script) }
      let(:campaign) { create(:power, :script => script, :account => @user.account) }
      let(:caller) { create(:caller, campaign_id: campaign.id) }

      before(:each) { create(:caller_session, :campaign => campaign, :caller => caller) }

      it "gets the entire list of questions and responses" do
        question = create(:question, :script => script)
        another_question = create(:question, :script => create(:script))
        2.times { create(:possible_response, :question => question) }
        get :call_details, :id => caller.id, :campaign_id => campaign.id
        expect(response).to be_ok
        expect(assigns(:questions_and_responses)).to have(1).item
        expect(assigns(:questions_and_responses)[question.text]).to have(3).items
      end

      it "shows only the campaigns in which the caller was involved" do
        another_campaign = create(:campaign, :script => script, :active => true, :account => @user.account)
        get :call_details, :id => caller.id, :campaign_id => campaign.id
        expect(response).to be_ok
        expect(assigns(:campaigns_data)).to eq([[campaign.name, campaign.id]])
      end

      it "defaults to the first campaign if campaign_id is not given" do
        get :call_details, :id => caller.id
        expect(response).to be_ok
        expect(assigns(:campaign)).to eq(campaign)
      end
    end
  end

  describe "reassign caller campaign" do
    let(:campaign){ create(:power, account: @user.account) }
    let(:other_campaign){ create(:power, account: @user.account) }
    let(:caller_record){ create(:caller, campaign_id: campaign.id) }
    let(:json_params) do
      {format: :json}
    end
    context 'when successful' do
      let(:message){ I18n.t('activerecord.successes.models.caller.campaign_change') }
      let(:params) do
        json_params.merge({
          campaign_id: other_campaign.id,
          id: caller_record.id
        })
      end
      it "should change caller campaign" do
        post :reassign_to_campaign, params
        expect(caller_record.reload.campaign_id).to eq(other_campaign.id)
      end
      it "renders a json success message when caller is reassigned" do
        post :reassign_to_campaign, params
        expect(response.body).to eq({message: message}.to_json)
      end
    end
    context 'when unsuccessful' do
      let(:message){ I18n.t('activerecord.errors.models.caller.campaign_change') }
      let(:params_bad) do
        json_params.merge({
          campaign_id: 'abc',
          id: caller_record.id
        })
      end
      it "renders a json failure message when the reassign campaign fails" do
        post :reassign_to_campaign, id: caller_record.id, campaign_id: 10000
        expect(response.body).to eq({message: message}.to_json)
      end
      it "renders a json failure message when the params given are not expected data types"
    end
  end

  context 'api' do
    describe 'index' do
      it 'returns all of the callers for that account' do
        3.times {create(:caller, account: account)}
        get :index, api_key: account.api_key, format: 'json'
        expect(JSON.parse(response.body).length).to eq(3)
      end
    end

    describe 'create' do
      it 'creates a new caller' do
        expect {
          post :create, api_key: account.api_key,
                        format: 'json',
                        caller: {name: 'caller', is_phones_only: 'true', campaign_id: create(:campaign, account: account)}
        }.to change {account.reload.callers.size}.by 1
      end

      it 'return validation errors' do
        post :create, caller: {username: ''}, api_key: account.api_key, format: 'json'
        expect(JSON.parse(response.body)).to eq({
          "errors" => {
            "username"    => ["can't be blank"]
          }
        })
      end
    end

    describe 'show' do
      it 'returns the caller as json' do
        caller = create(:caller, account: account)
        get :show, id: caller.id, api_key: account.api_key, format: 'json'
        returned = JSON.parse(response.body)
        expect(response.body).to eq(Caller.find(caller.id).to_json)
      end

      it 'gives an error if you try to access a caller from another account' do
        caller = create(:caller)
        get :show, id: caller.id, api_key: account.api_key, format: 'json'
        expect(JSON.parse(response.body)).to eq({"message" => "Cannot access caller"})
      end
    end

    describe 'update' do
      it 'gives a successful response if validations are met' do
        caller = create(:caller, account: account)
        put :update, id: caller.id, api_key: account.api_key, format: 'json', caller: {name: 'whatever'}
        expect(JSON.parse(response.body)).to eq({'message' => 'Caller updated'})
      end

      it 'returns validation errors for invalid requests' do
        caller = create(:caller, account: account)
        put :update, id: caller.id, api_key: account.api_key, format: 'json', caller: {username: ''}
        expect(JSON.parse(response.body)).to eq({
          "errors" => {
            "username" => ["can't be blank"]
          }
        })
      end
    end

    describe 'destroy' do
      it 'returns JSON saying the caller was archived' do
        caller = create(:caller, account: account)
        delete :destroy, id: caller.id, api_key: account.api_key, format: 'json'
        expect(JSON.parse(response.body)).to eq({'message' => 'Caller archived'})
      end

      it 'marks the caller as inactive' do
        caller = create(:caller, account: account)
        delete :destroy, id: caller.id, api_key: account.api_key, format: 'json'
        expect(caller.reload.active).to be_falsey
      end

      it 'will not delete a caller from another account' do
        caller = create(:caller)
        delete :destroy, id: caller.id, api_key: account.api_key, format: 'json'
        expect(JSON.parse(response.body)).to eq({'message' => 'Cannot access caller'})
      end
    end

    describe 'archived' do
      it 'should show archived callers' do
        caller = create(:caller, account: account, active: false)
        get :archived, api_key: account.api_key, format: 'json'
        expect(JSON.parse(response.body).length).to eq 1
      end
    end

    describe 'restore' do
      it 'should change a caller from inactive to active' do
        caller = create(:caller, account: account, active: false)
        put :restore, id: caller.id, api_key: account.api_key, format: 'json'
        expect(response.body).to eq("{\"message\":\"Caller restored\"}")
      end
    end
  end
end
