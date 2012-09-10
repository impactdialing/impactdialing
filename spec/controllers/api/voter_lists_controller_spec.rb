require 'spec_helper'

describe Api::VoterListsController do

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

  it "should throw error if file uploaded is not in the right format" do
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: @current_user.email, upload: {"datafile" => fixture_file_upload("/files/voter_list.xsl")}
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \\\"Save As\\\" to change it to one of these formats."})
  end

  it "should return 200 if list scheduled for upload" do
    VoterList.should_receive(:upload_file_to_s3)
    Resque.should_receive(:enqueue)
    post :create, api_key: '1mp@ctd1@l1ng',campaign_id: @campaign.id, account_id: @campaign.account.id.to_s, email: @current_user.email, upload: {"datafile" => fixture_file_upload("/files/invalid_voters_list.csv")}
    result = JSON.parse(response.body)
    response.code.should eq('200')
    JSON.parse(response.body).should eq({"status"=>"ok", "message"=>"Response will be sent to the callback url once the list upload is complete."})
  end






end