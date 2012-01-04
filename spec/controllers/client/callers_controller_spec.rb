require "spec_helper"

describe Client::CallersController do
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  def type_name
    'caller'
  end

  it "lists callers" do
    get :index
    response.code.should == '200'
  end

  it_should_behave_like 'all controllers of deletable entities'
  
  
  it "doesn't list deleted campaigns, in the dropdown list" do
    c1 = Factory(:campaign, :active => false, :account => user.account)
    c2 = Factory(:campaign, :active => true, :account => user.account)
    get :new
    assigns(:campaigns).should have(1).thing
    assigns(:campaigns)[0].should be_active
  end
  
  it "doesn't list robo campaigns, in the dropdown list " do
    c1 = Factory(:campaign, :active => true, :robo => false, :account => user.account)
    c2 = Factory(:campaign, :active => true, :robo => true, :account => user.account)
    get :new
    assigns(:campaigns).should have(1).thing
    assigns(:campaigns)[0].should be_active
  end

  it "should create a phones only caller" do
    name = "preethi_is_not_evil"
    post :create, :caller => {:name => name, :is_phones_only => true}
    caller = Caller.find_by_name(name)
    caller.should_not be_nil
    caller.is_phones_only.should be_true
  end

  it "should create a phones only caller" do
    email = "preethi@evil.com"
    post :create, :caller => {:email => email, :is_phones_only => false}
    caller = Caller.find_by_email(email)
    caller.should_not be_nil
    caller.is_phones_only.should be_false
  end
end
