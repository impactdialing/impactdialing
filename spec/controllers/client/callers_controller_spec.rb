require "spec_helper"

describe Client::CallersController do
  let(:account) {Factory(:account, api_key: 'abc123')}
  before(:each) { @user = Factory(:user, account: account) }

  context 'users' do
    before(:each) do
      login_as @user
    end

    def type_name
      'caller'
    end

    it "lists callers" do
      get :index
      response.code.should == '200'
    end



    it "doesn't list deleted campaigns, in the dropdown list" do
      c1 = Factory(:preview, :active => false, :account => @user.account)
      c2 = Factory(:predictive, :active => true, :account => @user.account)
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
      username = "preethi@evil.com"
      post :create, :caller => {:username => username, :is_phones_only => false, :campaign_id => "1234"}
      caller = Caller.find_by_username(username)
      caller.should_not be_nil
      caller.is_phones_only.should be_false
    end


    describe "call details report" do

      let(:script) { Factory(:script) }
      let(:campaign) { Factory(:progressive, :script => script, :account => @user.account) }
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
        another_campaign = Factory(:campaign, :script => script, :active => true, :account => @user.account)
        get :call_details, :id => caller.id, :campaign_id => campaign.id
        response.should be_ok
        assigns(:campaigns_data).should == [[campaign.name, campaign.id]]
      end

      it "defaults to the first campaign if campaign_id is not given" do
        get :call_details, :id => caller.id
        response.should be_ok
        assigns(:campaign).should == campaign
      end
    end
  end

  describe "reassign caller campaign" do
    it "should change caller campaign" do
      campaign = Factory(:progressive, :account => @user.account)
      other_campaign = Factory(:progressive, :account => @user.account)
      caller = Factory(:caller, campaign_id: campaign.id)
      post :reassign_to_campaign, id: caller.id, campaign_id: other_campaign.id
      caller.reload.campaign_id.should eq(other_campaign.id)
    end
  end

  context 'api' do
    describe 'index' do
      it 'returns all of the callers for that account' do
        3.times {Factory(:caller, account: account)}
        get :index, api_key: account.api_key, format: 'json'
        JSON.parse(response.body).length.should eq(3)
      end
    end

    describe 'create' do
      it 'creates a new caller' do
        lambda {
          post :create, api_key: account.api_key,
                        format: 'json',
                        caller: {name: 'caller', is_phones_only: 'true', campaign_id: 1}
        }.should change {account.reload.callers.size}.by 1
      end

      it 'return validation errors' do
        post :create, api_key: account.api_key, format: 'json'
        JSON.parse(response.body).should eq({"errors"=>{"username"=>["can't be blank"], "campaign_id"=>["can't be blank"]}})
      end
    end

    describe 'show' do
      it 'returns the caller as json' do
        caller = Factory(:caller, account: account)
        get :show, id: caller.id, api_key: account.api_key, format: 'json'
        response.body.should eq(caller.to_json)
      end

      it 'gives an error if you try to access a caller from another account' do
        caller = Factory(:caller)
        get :show, id: caller.id, api_key: account.api_key, format: 'json'
        JSON.parse(response.body).should eq({"message" => "Cannot access caller"})
      end
    end

    describe 'update' do
      it 'gives a successful response if validations are met' do
        caller = Factory(:caller, account: account)
        put :update, id: caller.id, api_key: account.api_key, format: 'json', caller: {name: 'whatever'}
        JSON.parse(response.body).should eq({'message' => 'Caller updated'})
      end

      it 'returns validation errors for invalid requests' do
        caller = Factory(:caller, account: account)
        put :update, id: caller.id, api_key: account.api_key, format: 'json', caller: {campaign_id: ''}
        JSON.parse(response.body).should eq({"errors"=>{"campaign_id"=>["can't be blank"]}})
      end
    end

    describe 'destroy' do
      it 'returns JSON saying the caller was deleted' do
        caller = Factory(:caller, account: account)
        delete :destroy, id: caller.id, api_key: account.api_key, format: 'json'
        JSON.parse(response.body).should eq({'message' => 'Caller deleted'})
      end

      it 'marks the caller as inactive' do
        caller = Factory(:caller, account: account)
        delete :destroy, id: caller.id, api_key: account.api_key, format: 'json'
        caller.reload.active.should be_false
      end

      it 'will not delete a caller from another account' do
        caller = Factory(:caller)
        delete :destroy, id: caller.id, api_key: account.api_key, format: 'json'
        JSON.parse(response.body).should eq({'message' => 'Cannot access caller'})
      end
    end

    describe 'deleted' do
      it 'should show deleted callers' do
        caller = Factory(:caller, account: account, active: false)
        get :deleted, api_key: account.api_key, format: 'json'
        JSON.parse(response.body).length.should eq 1
      end
    end

    describe 'restore' do
      it 'should change a caller from inactive to active' do
        caller = Factory(:caller, account: account, active: false)
        put :restore, id: caller.id, api_key: account.api_key, format: 'json'
        response.body.should eq("{\"message\":\"Caller restored\"}")
      end
    end
  end
end
