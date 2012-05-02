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
    c1 = Factory(:preview, :active => false, :account => user.account)
    c2 = Factory(:predictive, :active => true, :account => user.account)
    get :new
    assigns(:campaigns).should have(1).thing
    assigns(:campaigns)[0].should be_active
  end
  
  it "doesn't list robo campaigns, in the dropdown list " do
    c1 = Factory(:preview, :active => true, :account => user.account)
    c2 = Factory(:robo, :active => true,  :account => user.account)
    get :new
    assigns(:campaigns).should have(1).thing
    assigns(:campaigns)[0].should be_active
  end

  it "should create a phones only caller" do
    name = "preethi_is_not_evil"
    post :create, :caller => {:name => name, :is_phones_only => true, :campaign_id => "1234"}
    caller = Caller.find_by_name(name)
    caller.should_not be_nil
    caller.is_phones_only.should be_true
  end

  it "should create a phones only caller" do
    email = "preethi@evil.com"
    post :create, :caller => {:email => email, :is_phones_only => false, :campaign_id => "1234"}
    caller = Caller.find_by_email(email)
    caller.should_not be_nil
    caller.is_phones_only.should be_false
  end
  

  describe "call details report" do

    let(:script) { Factory(:script) }
    let(:campaign) { Factory(:progressive, :script => script, :account => user.account, robo:false) }
    let(:caller) { Factory(:caller, campaign_id: campaign.id) }

    before(:each) { Factory(:caller_session, :campaign => campaign, :caller => caller) }

    it "gets the entire list of questions and responses" do
      question = Factory(:question, :script => script)
      another_question = Factory(:question, :script => Factory(:script))
      2.times { Factory(:possible_response, :question => question) }
      get :call_details, :id => caller.id, :campaign_id => campaign.id
      response.should be_ok
      assigns(:questions_and_responses).should have(1).item
      assigns(:questions_and_responses)[question.text].should have(2).items
    end

    it "shows only the campaigns in which the caller was involved" do
      another_campaign = Factory(:campaign, :script => script, :active => true, :account => user.account)
      get :call_details, :id => caller.id, :campaign_id => campaign.id
      response.should be_ok
      assigns(:campaigns).should == [campaign]
    end

    it "shows only manual campaigns" do
      robo_campaign = Factory(:robo, :script => script, :account => user.account)
      Factory(:caller_session, :caller => caller, :campaign => robo_campaign)
      get :call_details, :id => caller.id, :campaign_id => campaign.id
      response.should be_ok
      assigns(:campaigns).should == [campaign]
    end

    it "defaults to the first campaign if campaign_id is not given" do
      get :call_details, :id => caller.id
      response.should be_ok
      assigns(:campaign).should == campaign
    end
  end
end
