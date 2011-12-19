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
