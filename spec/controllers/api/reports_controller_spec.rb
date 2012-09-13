require 'spec_helper'

describe Api::ReportsController do

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
    post :create, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('404')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Couldn't find Campaign without an ID"})
  end

  it 'should throw an error if campaign does not exist' do
    post :create, campaign_id: 400, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('404')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Couldn't find Campaign with id=400"})
  end


  it 'should throw an error if account id is not passed' do
    post :create, campaign_id: @campaign.id, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('404')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Couldn't find Account without an ID"})
  end

  it 'should throw an error if campaign does not belong to account ' do
    another_account = Factory(:account)
    post :create, campaign_id: @campaign.id, account_id: another_account.id.to_s, api_key: '1mp@ctd1@l1ng'
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Campaign is not assigned to the account"})
  end

  it "should throw error if email address does not match account" do
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: "axyz@abc.com"
    result = JSON.parse(response.body)
    response.code.should eq('401')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Unauthorized: Cannot access this account"})
  end

  it "should throw error if from date is not in correct format" do
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: @current_user.email, from_date: "32/31/2011", to_date: "12/31/2011"
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"invalid date Use mm/dd/yyyy HH:MM format"})
  end

  it "should throw error if to date is not in correct format" do
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: @current_user.email, from_date: "10/31/2011", to_date: "39/31/2011"
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"invalid date Use mm/dd/yyyy HH:MM format"})
  end

  it "should not validate date if download all voters" do
    Resque.should_receive(:enqueue)
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: @current_user.email, download_all_voters: "true"
    result = JSON.parse(response.body)
    response.code.should eq('200')
    JSON.parse(response.body).should eq({"status"=>"ok", "message"=>"Response will be sent to the callback url once the report is ready for download."})
  end

  it "should throw correct error if date not supplied" do
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: @current_user.email, download_all_voters: "false"
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"From and To date cannot be nil"})
  end

  it "should throw correct error if date is blank" do
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: @current_user.email, download_all_voters: "false", from_date: "", to_date: ""
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"invalid date Use mm/dd/yyyy HH:MM format"})
  end

  it "should return 200 if report scheduled for download" do
    Resque.should_receive(:enqueue)
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: @current_user.email, from_date: "10/31/2011 11:00", to_date: "11/30/2011 12:00"
    result = JSON.parse(response.body)
    response.code.should eq('200')
    JSON.parse(response.body).should eq({"status"=>"ok", "message"=>"Response will be sent to the callback url once the report is ready for download."})
  end


end