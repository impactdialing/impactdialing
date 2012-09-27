require "spec_helper"

describe Client::ScriptsController do
  let(:account) { Factory(:account, api_key: "abc123") }
  let(:user) { Factory(:user, :account => account) }

  describe "html" do
    before(:each) do
      login_as(user)
      request.env['HTTP_REFERER'] = 'http://referer'
    end

    it "lists voter fields to select" do
      post :create, script: {name: "script1"}, voter_field: ["Phone", "CustomID", "LastName", "FirstName", "MiddleName", "Suffix", "Email", "address", "city", "state", "zip_code", "country"]
      response.should redirect_to(client_scripts_url)
      Script.find_by_name("script1").voter_fields.should eq(Voter.upload_fields.to_json)
    end

    it "shows the list of voter fields which were selected" do
      script = Factory(:script, :account => account, :active => true)
      selected_voter_fields = ["Phone", "CustomID", "LastName", "FirstName"]
      post :create, script: {name: "script1"}, voter_field: selected_voter_fields
      response.should redirect_to(client_scripts_url)
      Script.find_by_name("script1").voter_fields.should eq(selected_voter_fields.to_json)
    end

  end


  describe "api" do
    before(:each) do
      @user = Factory(:user, account_id: account.id)
    end

    describe "index" do
      it "should list active scripts for an account" do
        active_script = Factory(:script, :account => account, :active => true)
        inactive_script = Factory(:script, :account => account, :active => false)
        get :index, :api_key=> 'abc123', :format => "json"
        JSON.parse(response.body).length.should eq(1)
      end

      it "should not list active scripts for an account with wrong api key" do
        active_script = Factory(:script, :account => account, :active => true)
        inactive_script = Factory(:script, :account => account, :active => false)
        get :index, :api_key=> 'def12', :format => "json"
        JSON.parse(response.body).should eq({"status"=>"error", "code"=>"401", "message"=>"Unauthorized"})
      end
    end

    describe "show" do
      it "should show script" do
        active_script = Factory(:script, :account => account, :active => true)
        script_text = Factory(:script_text, script_order: 1, script: active_script)
        get :show, id: active_script.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq(active_script.to_json)
      end
    end

    describe "edit" do
      it "should show script" do
        active_script = Factory(:script, :account => account, :active => true)
        script_text = Factory(:script_text, script_order: 1, script: active_script)
        get :edit, id: active_script.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq(active_script.to_json)
      end
    end

    describe "destroy" do
      it "should delete script" do
        active_script = Factory(:script, :account => account, :active => true)
        delete :destroy, :id=> active_script.id, :api_key=> 'abc123', :format => "json"
        response.body.should == "{\"message\":\"Script deleted\"}"
      end

      it "should not delete a script from another account" do
        another_account = Factory(:account, :activated => true, api_key: "123abc")
        another_user = Factory(:user, account_id: another_account.id)

        active_script = Factory(:script, :account => account, :active => true)
        delete :destroy, :id=> active_script.id, :api_key=> '123abc', :format => "json"
        response.body.should == "{\"message\":\"Cannot access script.\"}"
      end

      it "should not delete and return validation error" do
        active_script = Factory(:script, :account => account, :active => true)
        predictive_campaign = Factory(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now, script: active_script)
        delete :destroy, :id=> active_script.id, :api_key=> 'abc123', :format => "json"
        response.body.should == "{\"errors\":{\"base\":[\"This script cannot be deleted, as it is currently assigned to an active campaign.\"]}}"
      end

    end

    describe "create" do
      it "should create a new script" do
        lambda {
          post :create , :script => {name: "abc"}, :api_key=> "abc123", :format => "json"
        }.should change {account.reload.scripts.size} .by(1)
        JSON.parse(response.body)['script']['name'].should  eq('abc')
      end

      it "should throw validation error" do
         lambda {
            post :create , :script => {}, :api_key=> "abc123", :format => "json"
          }.should change {account.reload.scripts.size} .by(0)
          response.body.should eq("{\"errors\":{\"name\":[\"can't be blank\"]}}")
      end

    end

    describe "update" do
      it "should update an existing script" do
        active_script = Factory(:script, :account => account, :active => true)
        lambda {
          put :update , id: active_script.id, :script => {name: "def"}, :api_key=> "abc123", :format => "json"
        }.should change {account.reload.scripts.size} .by(0)
        response.body.should  eq("{\"message\":\"Script updated\"}")
      end

      it "should throw validation error" do
        active_script = Factory(:script, :account => account, :active => true)
        lambda {
          put :update , id: active_script.id, :script => {name: nil}, :api_key=> "abc123", :format => "json"
        }.should change {account.reload.scripts.size} .by(0)
        response.body.should  eq("{\"errors\":{\"name\":[\"can't be blank\"]}}")
      end


    end

    describe "deleted" do

      it "should show deleted scripts" do
        active_script = Factory(:script, :account => account, :active => false)
        get :deleted, :api_key=> 'abc123', :format => "json"
        JSON.parse(response.body).length.should eq(1)
      end
    end

    describe "restore" do

      it "should restore inactive campaign" do
        in_active_active_script = Factory(:script, :account => account, :active => false)
        put :restore, script_id: in_active_active_script.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq("{\"message\":\"Script restored\"}")
      end
    end

    describe "questions_answered" do
      it "should return hash of question answer count" do
        active_script = Factory(:script, :account => account, :active => true)
        question = Factory(:question, :script => active_script)
        answer1 = Factory(:answer, :voter => Factory(:voter), campaign: Factory(:campaign), :possible_response => Factory(:possible_response), :question => question)
        get :questions_answered, id: active_script.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq("{\"data\":{\"#{question.id}\":#{1}}}")
      end
    end

    describe "possible_responses_answered" do
      it "should return hash of possible response answer count" do
        active_script = Factory(:script, :account => account, :active => true)
        active_script1 = Factory(:script, :account => Factory(:account), :active => true)
        question = Factory(:question, :script => active_script)
        answer1 = Factory(:answer, :voter => Factory(:voter), campaign: Factory(:campaign), :possible_response => Factory(:possible_response), :question => question)
        get :possible_responses_answered, id: active_script.id, :api_key=> 'abc123', :format => "json"
        response.body.should eq("{\"data\":{}}")
      end
    end




  end

end
