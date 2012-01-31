require 'spec_helper'

describe Api::LeadsController do
  
  before :each do
    @current_user = Factory(:user)
    @campaign = Factory(:campaign, :account => @current_user.account)
  end
  it 'should throw an error if api_key is not passed' do
    post :create, phone_number: "1234567890"
    result = JSON.parse(response.body)
    result['error']['code'].should eq('401')
    result['error']['message'].should eq("UnauthorizedAccess")
  end
  
  
  it 'should throw an error if campaign id is not passed' do
    post :create, phone_number: "1234567890", api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('404')
    result['error']['message'].should eq("Couldn't find Campaign without an ID")
  end
  
  it 'should throw an error if campaign does not exist' do
    post :create, phone_number: "1234567890", campaign_id: 400, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('404')
    result['error']['message'].should eq("Couldn't find Campaign with ID=400")
  end
  

  it 'should throw an error if account id is not passed' do
    post :create, phone_number: "1234567890", campaign_id: @campaign.id, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('404')
    result['error']['message'].should eq("Couldn't find Account without an ID")
  end

  it 'should throw an error if campaign does not belong to account ' do
    another_account = Factory(:account)
    post :create, phone_number: "1234567890", campaign_id: @campaign.id, account_id: another_account.id.to_s, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('400')
    result['error']['message'].should eq('Campaign is not assigned to the account')
  end
  
  it 'should throw an error if if phone number is not passed ' do
    post :create, campaign_id: @campaign.id, account_id: @campaign.account_id.to_s, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error']['code'].should eq('400')
    result['error']['message'].should eq("Validation failed: Phone can't be blank, Phone is too short (minimum is 10 characters)")
  end
  
  it 'should return success if lead is imported ' do
    post :create, phone_number: "1234567890", campaign_id: @campaign.id, account_id: @campaign.account_id.to_s, api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    result['error'].should be_nil
    result['success']['code'].should eq("200")
    result['success']['message'].should eq("Lead Imported Successfully")
  end
  
  it "should create a voter list if none exist with name web form" do
    post :create, campaign_id: @campaign.id, phone_number: "1234567890", account_id: @campaign.account_id.to_s, api_key: '1mp@ctd1@l1ng'
    @campaign.voter_lists.length.should eq(1)
  end
    
  it "should add a voter with priority 1" do
    post :create, campaign_id: @campaign.id, phone_number: "1234567890", account_id: @campaign.account_id.to_s, api_key: '1mp@ctd1@l1ng'
    @campaign.all_voters.length.should eq(1)
    @campaign.all_voters.first.priority.should eq("1")
  end
    
end