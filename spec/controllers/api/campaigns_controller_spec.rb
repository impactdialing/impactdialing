require 'spec_helper'

describe Api::CampaignsController do
  before :each do
    @current_user = Factory(:user)
    @campaign = Factory(:campaign, :account => @current_user.account)
  end
  
  it "should throw error if api key is not passed" do
    get :index
    result = JSON.parse(response.body)
    response.code.should eq('401')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"UnauthorizedAccess"})    
  end
  
  it "should throw error if account is not passed" do
    get :index,api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    response.code.should eq('404')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Couldn't find Account without an ID"})    
  end
  
  it "should throw error if email address is blank" do
    get :index,api_key: '1mp@ctd1@l1ng',account_id: @current_user.account.id
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Email cannot be blank"})    
  end
  
  it "should throw error if email address does not match account" do
    get :index,api_key: '1mp@ctd1@l1ng',account_id: @current_user.account.id, email: "abc@abc.com"
    result = JSON.parse(response.body)
    response.code.should eq('401')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Unauthorized: Cannot access this account"})    
  end
  
  it "should return no campaigns if account has no campaigns" do
    user = Factory(:user)
    get :index,api_key: '1mp@ctd1@l1ng',account_id: user.account.id, email: user.email
    result = JSON.parse(response.body)
    response.code.should eq('200')
    JSON.parse(response.body).should eq({"status"=>"ok", "message"=>"Success", "data"=>[]})    
  end
  
  it "should return  campaigns if account has  campaigns" do
    campaign = Factory(:campaign, :account => @current_user.account)
    get :index,api_key: '1mp@ctd1@l1ng',account_id: @current_user.account.id, email: @current_user.email
    result = JSON.parse(response.body)
    response.code.should eq('200')
    JSON.parse(response.body).should eq({"status"=>"ok", "message"=>"Success", "data"=>[{"id"=>@campaign.id, "name"=>@campaign.name}, {"id"=>campaign.id, "name"=>campaign.name}]})    
  end
  
  it "should not return deleted campaigns" do
    campaign = Factory(:campaign, :account => @current_user.account, active:false)
    get :index,api_key: '1mp@ctd1@l1ng',account_id: @current_user.account.id, email: @current_user.email
    result = JSON.parse(response.body)
    response.code.should eq('200')
    JSON.parse(response.body).should eq({"status"=>"ok", "message"=>"Success", "data"=>[{"id"=>@campaign.id, "name"=>@campaign.name}]})    
  end
  
  
  
  
  
  
end
