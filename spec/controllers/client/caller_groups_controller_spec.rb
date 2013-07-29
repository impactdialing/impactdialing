require 'spec_helper'

describe Client::CallerGroupsController do
  let(:account) {create(:account, api_key: 'abc123')}
  before(:each) do
    @user = create(:user, account_id: account.id)
  end

  describe 'index' do
    it 'returns all of the caller groups' do
      2.times {create(:caller_group, account: account)}
      get :index, api_key: account.api_key, format: 'json'
      JSON.parse(response.body).length.should eq(2)
    end

    it 'gives an error for an invalid api key' do
      get :index, api_key: 'bad', format: 'json'
      JSON.parse(response.body).should eq({"status"=>"error", "code"=>"401", "message"=>"Unauthorized"})
    end
  end

  describe 'create' do
    it 'creates a new caller group' do
      lambda {
        post :create, api_key: account.api_key,
                      format: 'json',
                      caller_group: {name: 'caller_group', campaign_id: 1}
      }.should change {account.reload.caller_groups.size}.by 1
    end

    it 'returns the caller group as json' do
      post :create, api_key: account.api_key,
                    format: 'json',
                    caller_group: {name: 'caller_group', campaign_id: 1}
      response.body.should eq CallerGroup.last.to_json
    end

    it 'gives a validation error if the name is missing' do
      post :create, api_key: account.api_key, format: 'json', caller_group: {campaign_id: 1}
      JSON.parse(response.body).should eq({"errors"=>{"name"=>["can't be blank"]}})
    end

    it 'gives a validation error if the campaign id is missing' do
      post :create, api_key: account.api_key, format: 'json', caller_group: {name: 'caller group'}
      JSON.parse(response.body).should eq({"errors"=>{"campaign_id"=>["can't be blank"]}})
    end
  end

  describe 'show' do
    it 'should return the caller group as json' do
      caller_group = create(:caller_group, account: account)
      get :show, id: caller_group.id, api_key: account.api_key, format: 'json'
      response.body.should eq caller_group.to_json
    end

    it 'does not show a campaign from another account' do
      caller_group = create(:caller_group)
      get :show, id: caller_group.id, api_key: account.api_key, format: 'json'
      JSON.parse(response.body).should eq({"message" => "Cannot access caller group"})
    end
  end

  describe 'update' do
    it 'gives a successful response if validations are met' do
      caller_group = create(:caller_group, account: account)
      put :update, id: caller_group.id, api_key: account.api_key, format: 'json', caller_group: {name: 'new name'}
      JSON.parse(response.body).should eq({'message' => 'Caller Group updated'})
    end

    it 'throws a validation error if a required attribute is invalid' do
      caller_group = create(:caller_group, account: account)
      put :update, id: caller_group.id, api_key: account.api_key, format: 'json', caller_group: {name: ''}
      JSON.parse(response.body).should eq({"errors"=>{"name"=>["can't be blank"]}})
    end
  end

  describe 'destroy' do
    it 'returns JSON saying the caller group was deleted' do
      caller_group = create(:caller_group, account: account)
      delete :destroy, id: caller_group.id, api_key: account.api_key, format: 'json'
      JSON.parse(response.body).should eq({'message' => 'Caller Group deleted'})
    end

    it 'deletes the caller group' do
      caller_group = create(:caller_group, account: account)
      lambda {
        delete :destroy, id: caller_group.id, api_key: account.api_key, format: 'json'
      }.should change {account.reload.caller_groups.size}.by -1
    end

    it 'will not delete a caller group from another account' do
      caller_group = create(:caller_group)
      delete :destroy, id: caller_group.id, api_key: account.api_key, format: 'json'
      JSON.parse(response.body).should eq({'message' => 'Cannot access caller group'})
    end
  end
end
