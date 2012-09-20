require 'spec_helper'

describe Api::CallersController do

  before :each do
    @current_user = Factory(:user)
    @campaign = Factory(:predictive, :account => @current_user.account)
  end

  it 'should throw an error if api_key is not passed' do
    post :create
    result = JSON.parse(response.body)
    response.code.should eq('401')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"UnauthorizedAccess"})
  end


  it 'should throw an error if campaign id is not passed' do
    post :create, email: "email@email.com", api_key: '1mp@ctd1@l1ng'
    response.code.should eq('404')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Couldn't find Campaign without an ID"})
  end

  it 'should throw an error if campaign does not exist' do
    post :create, campaign_id: 400, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('404')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Couldn't find Campaign with id=400"})
  end


  it 'should throw an error if account id is not passed' do
    post :create,  campaign_id: @campaign.id, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('404')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Couldn't find Account without an ID"})
  end

  it 'should throw an error if campaign does not belong to account ' do
    another_account = Factory(:account)
    post :create, campaign_id: @campaign.id, account_id: another_account.id.to_s, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Campaign is not assigned to the account"})
  end

  it 'should throw an error if caller email is blank ' do
    post :create, campaign_id: @campaign.id, account_id: @campaign.account_id.to_s, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Email cannot be blank"})
  end

  it 'should throw an error if caller email is already taken ' do
    Factory(:caller, email: 'abc@abc.com', campaign_id: @campaign.id, account_id: @campaign.account_id)
    post :create, email: 'abc@abc.com', campaign_id: @campaign.id, account_id: @campaign.account_id.to_s, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Validation failed: Email has already been taken"})
  end

  it 'should create caller ' do
    post :create, email: 'abc@abc.com', campaign_id: @campaign.id, account_id: @campaign.account_id.to_s, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('200')
    JSON.parse(response.body).should eq({"status"=>"ok", "message"=>"Caller created successfully"})
  end



end
