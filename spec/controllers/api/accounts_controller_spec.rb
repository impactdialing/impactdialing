require 'spec_helper'

describe Api::AccountsController do
  
  
  it "should throw error if api key is not passed" do
    # account = Factory(:account)
    # user = Factory(:user, email:"test@test.com", )
    get :id
    result = JSON.parse(response.body)
    response.code.should eq('401')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"UnauthorizedAccess"})    
  end
  
  it "should throw error if email address is blank" do
    get :id , api_key: '1mp@ctd1@l1ng'
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"Email cannot be blank"})    
  end
  
  it "should throw error if user cannot be authenticated" do
    account = Factory(:account)
    user = Factory(:user, email:"test@test.com",new_password: "password" )    
    get :id , api_key: '1mp@ctd1@l1ng', email: "test@test.com", password: "pass"
    result = JSON.parse(response.body)
    response.code.should eq('400')
    JSON.parse(response.body).should eq({"status"=>"error", "message"=>"The email or password you entered was incorrect."})    
  end
  
  it "should return account id when user is authenticated" do
    account = Factory(:account)
    user = Factory(:user, email:"test@test.com",new_password: "password",account_id: account.id )    
    get :id , api_key: '1mp@ctd1@l1ng', email: "test@test.com", password: "password"
    result = JSON.parse(response.body)
    response.code.should eq('200')
    JSON.parse(response.body).should eq({"status"=>"ok", "message"=>"Success", "data"=>{"id"=>account.id}})    
  end
  
  
end  
