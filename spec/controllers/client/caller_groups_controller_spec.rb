require 'spec_helper'

describe Client::CallerGroupsController, :type => :controller do
  let(:account) {create(:account, api_key: 'abc123')}
  before(:each) do
    @user = create(:user, account_id: account.id)
  end

  describe 'index' do
    it 'returns all of the caller groups' do
      2.times {create(:caller_group, account: account)}
      get :index, api_key: account.api_key, format: 'json'
      expect(JSON.parse(response.body).length).to eq(2)
    end

    it 'gives an error for an invalid api key' do
      get :index, api_key: 'bad', format: 'json'
      expect(JSON.parse(response.body)).to eq({"status"=>"error", "code"=>"401", "message"=>"Unauthorized request. Please provide a valid API key or create an account."})
    end
  end

  describe 'create' do
    it 'creates a new caller group' do
      expect {
        post :create, api_key: account.api_key,
                      format: 'json',
                      caller_group: {name: 'caller_group', campaign_id: 1}
      }.to change {account.reload.caller_groups.size}.by 1
    end

    it 'returns the caller group as json' do
      post :create, api_key: account.api_key,
                    format: 'json',
                    caller_group: {name: 'caller_group', campaign_id: 1}
      expect(response.body).to eq CallerGroup.last.to_json
    end

    it 'gives a validation error if the name is missing' do
      post :create, api_key: account.api_key, format: 'json', caller_group: {campaign_id: 1}
      expect(JSON.parse(response.body)).to eq({"errors"=>{"name"=>["can't be blank"]}})
    end

    it 'gives a validation error if the campaign id is missing' do
      post :create, api_key: account.api_key, format: 'json', caller_group: {name: 'caller group'}
      expect(JSON.parse(response.body)).to eq({"errors"=>{"campaign_id"=>["can't be blank"]}})
    end
  end

  describe 'show' do
    it 'should return the caller group as json' do
      caller_group = create(:caller_group, account: account)
      get :show, id: caller_group.id, api_key: account.api_key, format: 'json'
      expect(response.body).to eq caller_group.to_json
    end

    it 'does not show a campaign from another account' do
      caller_group = create(:caller_group)
      get :show, id: caller_group.id, api_key: account.api_key, format: 'json'
      expect(JSON.parse(response.body)).to eq({"message" => "Cannot access caller group"})
    end
  end

  describe 'update' do
    it 'gives a successful response if validations are met' do
      caller_group = create(:caller_group, account: account)
      put :update, id: caller_group.id, api_key: account.api_key, format: 'json', caller_group: {name: 'new name'}
      expect(JSON.parse(response.body)).to eq({'message' => 'Caller Group updated'})
    end

    it 'throws a validation error if a required attribute is invalid' do
      caller_group = create(:caller_group, account: account)
      put :update, id: caller_group.id, api_key: account.api_key, format: 'json', caller_group: {name: ''}
      expect(JSON.parse(response.body)).to eq({"errors"=>{"name"=>["can't be blank"]}})
    end
  end

  describe 'destroy' do
    it 'returns JSON saying the caller group was deleted' do
      caller_group = create(:caller_group, account: account)
      delete :destroy, id: caller_group.id, api_key: account.api_key, format: 'json'
      expect(JSON.parse(response.body)).to eq({'message' => 'Caller Group deleted'})
    end

    it 'deletes the caller group' do
      caller_group = create(:caller_group, account: account)
      expect {
        delete :destroy, id: caller_group.id, api_key: account.api_key, format: 'json'
      }.to change {account.reload.caller_groups.size}.by -1
    end

    it 'will not delete a caller group from another account' do
      caller_group = create(:caller_group)
      delete :destroy, id: caller_group.id, api_key: account.api_key, format: 'json'
      expect(JSON.parse(response.body)).to eq({'message' => 'Cannot access caller group'})
    end
  end
end
