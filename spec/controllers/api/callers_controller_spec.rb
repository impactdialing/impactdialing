require 'spec_helper'

describe Api::CallersController do
  
  before :each do
    @current_user = Factory(:user)
    @campaign = Factory(:campaign, :account => @current_user.account)
  end
  
  it 'should throw an error if api_key is not passed' do
    post :create
    result = JSON.parse(response.body)
    result['error']['code'].should eq('401')
    result['error']['message'].should eq("UnauthorizedAccess")
  end
  
  
  it 'should throw an error if campaign id is not passed' do
    post :create, email: "email@email.com", api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('400')
    result['error']['message'].should eq("Validation failed: Campaign can't be blank")
  end
  
  it 'should throw an error if campaign does not exist' do
    post :create, campaign_id: 400, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('404')
    result['error']['message'].should eq("Couldn't find Campaign with ID=400")
  end
  

  it 'should throw an error if account id is not passed' do
    post :create,  campaign_id: @campaign.id, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('404')
    result['error']['message'].should eq("Couldn't find Account without an ID")
  end

  it 'should throw an error if campaign does not belong to account ' do
    another_account = Factory(:account)
    post :create, campaign_id: @campaign.id, account_id: another_account.id, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('400')
    result['error']['message'].should eq('Campaign is not assigned to the account')
  end
  
  it 'should throw an error if caller email is blank ' do
    another_account = Factory(:account)
    post :create, campaign_id: @campaign.id, account_id: @campaign.account_id, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('400')
    result['error']['message'].should eq('Email cannot be blank')
  end
  
  it 'should throw an error if caller email is already taken ' do
    Factory(:caller, email: 'abc@abc.com', campaign_id: @campaign.id, account_id: @campaign.account_id)
    post :create, email: 'abc@abc.com', campaign_id: @campaign.id, account_id: @campaign.account_id, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('400')
    result['error']['message'].should eq('Validation failed: Email has already been taken')
  end
  
  
  
  
end
