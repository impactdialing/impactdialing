require "spec_helper"

describe Client::CampaignsController do

  let(:account) { create(:account, :activated => true) }
  let(:user) { create(:user, :account => account) }

  describe "html format" do
    before(:each) do
      login_as user
    end

    it "lists active campaigns" do
      active_campaign = create(:preview, :account => account, :active => true)
      inactive_campaign = create(:power, :account => account, :active => false)
      get :index
      assigns(:campaigns).should == [active_campaign]
    end

    describe 'show' do
      let(:campaign) {create(:preview, :account => account)}

      after(:each) do
        response.should be_ok
      end
    end

    it "deletes campaigns" do
      request.env['HTTP_REFERER'] = 'http://referer'
      campaign = create(:preview, :account => account, :active => true)
      delete :destroy, :id => campaign.id
      campaign.reload.should_not be_active
      response.should redirect_to 'http://test.host/client/campaigns'
    end

    it "restore campaigns" do
      request.env['HTTP_REFERER'] = 'http://referer'
      campaign = create(:preview, :account => account, :active => true)
      put :restore, :campaign_id => campaign.id
      campaign.reload.should be_active
      response.should redirect_to 'http://test.host/client/campaigns'
    end

    it "creates a new campaign" do
      script = create(:script, :account => account)
      callers = 3.times.map{create(:caller, :account => account)}
      lambda {
        post :create , :campaign => {name: "abc", caller_id:"1234567890", script_id: script.id,
          type: "Preview", time_zone: "Pacific Time (US & Canada)", start_time:  Time.new(2011, 1, 1, 9, 0, 0), end_time: Time.new(2011, 1, 1, 21, 0, 0)}
      }.should change {account.reload.campaigns.size} .by(1)
      campaign = account.campaigns.last
      campaign.type.should == 'Preview'
      campaign.script.should == script
      campaign.account.callers.should == callers
    end


  end



  describe "api" do

    before(:each) do
      @user = create(:user, account_id: account.id)
    end

    describe "index" do

      it "should list active campaigns for an account" do
        preview_campaign = create(:preview, :account => account, :active => true)
        predictive_campaign = create(:predictive, :account => account, :active => true)
        inactive_campaign = create(:power, :account => account, :active => false)
        get :index, :api_key=> account.api_key, :format => "json"
        JSON.parse(response.body).length.should eq(2)
      end

      it "should not list active campaigns for an account with wrong api key" do
        preview_campaign = create(:preview, :account => account, :active => true)
        predictive_campaign = create(:predictive, :account => account, :active => true)
        inactive_campaign = create(:power, :account => account, :active => false)
        get :index, :api_key=> 'abc12', :format => "json"
        JSON.parse(response.body).should eq({"status"=>"error", "code"=>"401", "message"=>"Unauthorized"})
      end

    end

    describe "show" do
      it "should give campaign details" do
        campaign = create(:predictive, :account => account, :active => true, name: "Campaign 1")
        get :show, :id=> campaign.id, :api_key=> account.api_key, :format => "json"
        JSON.parse(response.body)['predictive']['name'].should eq("Campaign 1")
      end
    end

    describe "edit" do
      it "should give campaign details" do
        predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now, name: "Campaign 2")
        get :edit, :id=> predictive_campaign.id, :api_key=> account.api_key, :format => "json"
        JSON.parse(response.body)['predictive']['name'].should eq("Campaign 2")
      end
    end

    describe "destroy" do
      it "should delete campaign" do
        predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now)
        delete :destroy, :id=> predictive_campaign.id, :api_key=> account.api_key, :format => "json"
        response.body.should == "{\"message\":\"Campaign deleted\"}"
      end

      it "should not delete a campaign from another account" do
        another_account = create(:account, :activated => true)
        another_user = create(:user, account_id: another_account.id)

        predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now)
        delete :destroy, :id=> predictive_campaign.id, :api_key=> another_account.api_key, :format => "json"
        response.body.should == "{\"message\":\"Cannot access campaign.\"}"
      end

      it "should not delete and return validation error" do
        caller = create(:caller)
        predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now, callers: [caller])
        delete :destroy, :id=> predictive_campaign.id, :api_key=> account.api_key, :format => "json"
        response.body.should == "{\"errors\":{\"caller_id\":[],\"base\":[\"There are currently callers assigned to this campaign. Please assign them to another campaign before deleting this one.\"]}}"
      end
    end

    describe "create" do
      it "should create a new campaign" do
        script = create(:script, :account => account)
        callers = 3.times.map{create(:caller, :account => account)}
        lambda {
          post :create , :campaign => {name: "abc", caller_id:"1234567890", script_id: script.id,
            type: "Preview", time_zone: "Pacific Time (US & Canada)", start_time:  Time.new(2011, 1, 1, 9, 0, 0), end_time: Time.new(2011, 1, 1, 21, 0, 0)}, :api_key=> account.api_key, :format => "json"
        }.should change {account.reload.campaigns.size} .by(1)
        JSON.parse(response.body)['campaign']['name'].should  eq('abc')
      end

      it "should throw validation error" do
        script = create(:script, :account => account)
        callers = 3.times.map{create(:caller, :account => account)}
        lambda {
          post :create , :campaign => {name: "abc", caller_id:"123456", script_id: script.id,
            type: "Preview", time_zone: "Pacific Time (US & Canada)", start_time:  Time.new(2011, 1, 1, 9, 0, 0), end_time: Time.new(2011, 1, 1, 21, 0, 0)}, :api_key=> account.api_key, :format => "json"
        }.should change {account.reload.campaigns.size} .by(0)
        response.body.should eq("{\"errors\":{\"caller_id\":[],\"base\":[\"Caller ID must be a 10-digit North American phone number or begin with \\\"+\\\" and the country code\"]}}")

      end

    end

    describe "update" do
      it "should update an existing campaign" do
        campaign = create(:predictive, name: "abc", account: account)
        lambda {
          put :update , id: campaign.id, :campaign => {name: "def"}, :api_key=> account.api_key, :format => "json"
        }.should change {account.reload.campaigns.size} .by(0)
        response.body.should  eq("{\"message\":\"Campaign updated\"}")
      end

      it "should update voter lists for existing campaign" do
        voter_list = create(:voter_list, enabled: true)
        campaign = create(:predictive, name: "abc", account: account, voter_lists: [voter_list])
        lambda {
          put :update , id: campaign.id, :campaign => {name: "def", :voter_lists_attributes=> {"0"=>{"id"=>"#{voter_list.id}", "enabled"=> "0"}}}, :api_key=> account.api_key, :format => "json"
        }.should change {account.reload.campaigns.size} .by(0)
        response.body.should  eq("{\"message\":\"Campaign updated\"}")
        voter_list.reload.enabled.should be_false
      end


      it "should throw validation error" do
        campaign = create(:predictive, name: "abc", account: account)
        lambda {
          put :update , id: campaign.id, :campaign => {caller_id: "123"}, :api_key=> account.api_key, :format => "json"
        }.should change {account.reload.campaigns.size} .by(0)
        response.body.should  eq("{\"errors\":{\"caller_id\":[],\"base\":[\"Caller ID must be a 10-digit North American phone number or begin with \\\"+\\\" and the country code\"]}}")
      end


    end

    describe "deleted" do

      it "should show deleted campaigns" do
        manual_campaign = create(:preview, :account => account, :active => true)
        inactive_campaign = create(:power, :account => account, :active => false)
        get :deleted, :api_key=> account.api_key, :format => "json"
        JSON.parse(response.body).length.should eq(1)
      end
    end

    describe "restore" do

      it "should restore inactive campaign" do
        inactive_campaign = create(:power, :account => account, :active => false)
        put :restore, campaign_id: inactive_campaign.id, :api_key=> account.api_key, :format => "json"
        response.body.should eq("{\"message\":\"Campaign restored\"}")
      end
    end
  end
end
