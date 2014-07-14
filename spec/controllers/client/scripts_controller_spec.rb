require "spec_helper"

describe Client::ScriptsController, :type => :controller do
  let(:account) { create(:account) }
  let(:user) { create(:user, :account => account) }

  describe "html" do
    before(:each) do
      login_as(user)
      request.env['HTTP_REFERER'] = 'http://referer'
    end

    it "lists voter fields to select" do
      post :create, script: {name: "script1"}, voter_field: ["phone", "custom_id", "last_name", "first_name", "middle_name", "suffix", "email", "address", "city", "state", "zip_code", "country"]
      expect(response).to redirect_to(client_scripts_url)
      expect(Script.find_by_name("script1").voter_fields).to eq(Voter::UPLOAD_FIELDS.to_json)
    end

    it "shows the list of voter fields which were selected" do
      script = create(:script, :account => account, :active => true)
      selected_voter_fields = ["phone", "custom_id", "last_name", "first_name"]
      post :create, script: {name: "script1"}, voter_field: selected_voter_fields
      expect(response).to redirect_to(client_scripts_url)
      expect(Script.find_by_name("script1").voter_fields).to eq(selected_voter_fields.to_json)
    end

  end


  describe "api" do
    before(:each) do
      @user = create(:user, account_id: account.id)
    end

    describe "index" do
      it "should list active scripts for an account" do
        active_script = create(:script, :account => account, :active => true)
        inactive_script = create(:script, :account => account, :active => false)
        get :index, :api_key=> account.api_key, :format => "json"
        expect(JSON.parse(response.body).length).to eq(1)
      end

      it "should not list active scripts for an account with wrong api key" do
        active_script = create(:script, :account => account, :active => true)
        inactive_script = create(:script, :account => account, :active => false)
        get :index, :api_key=> 'def12', :format => "json"
        expect(JSON.parse(response.body)).to eq({"status"=>"error", "code"=>"401", "message"=>"Unauthorized request. Please provide a valid API key or create an account."})
      end
    end

    describe "show" do
      it "should show script" do
        active_script = create(:script, :account => account, :active => true)
        script_text = create(:script_text, script_order: 1, script: active_script)
        get :show, id: active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq(active_script.to_json)
      end
    end

    describe "edit" do
      it "should show script" do
        active_script = create(:script, :account => account, :active => true)
        script_text = create(:script_text, script_order: 1, script: active_script)
        get :edit, id: active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq(active_script.to_json)
      end
    end

    describe "destroy" do
      it "should delete script" do
        active_script = create(:script, :account => account, :active => true)
        delete :destroy, :id=> active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq("{\"message\":\"Script deleted\"}")
      end

      it "should not delete a script from another account" do
        another_account = create(:account, :activated => true, api_key: "123abc")
        another_user = create(:user, account_id: another_account.id)

        active_script = create(:script, :account => account, :active => true)
        delete :destroy, :id=> active_script.id, :api_key=> another_account.api_key, :format => "json"
        expect(response.body).to eq("{\"message\":\"Cannot access script.\"}")
      end

      it "should not delete and return validation error" do
        active_script = create(:script, :account => account, :active => true)
        predictive_campaign = create(:predictive, :account => account, :active => true, start_time: Time.now, end_time: Time.now, script: active_script)
        delete :destroy, :id=> active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq("{\"errors\":{\"base\":[\"This script cannot be deleted, as it is currently assigned to an active campaign.\"]}}")
      end

    end

    describe "create" do
      it "should create a new script" do
        expect {
          post :create , :script => {name: "abc"}, :api_key=> account.api_key, :format => "json"
        }.to change {account.reload.scripts.size} .by(1)
        expect(JSON.parse(response.body)['name']).to  eq('abc')
      end

      it "should throw validation error" do
         expect {
            post :create , :script => {}, :api_key=> account.api_key, :format => "json"
          }.to change {account.reload.scripts.size} .by(0)
          expect(response.body).to eq("{\"errors\":{\"name\":[\"can't be blank\"]}}")
      end

    end

    describe "update" do
      it "should update an existing script" do
        active_script = create(:script, :account => account, :active => true)
        expect {
          put :update , id: active_script.id, :script => {name: "def"}, :api_key=> account.api_key, :format => "json"
        }.to change {account.reload.scripts.size} .by(0)
        expect(response.body).to  eq("{\"message\":\"Script updated\"}")
      end

      it "should throw validation error" do
        active_script = create(:script, :account => account, :active => true)
        expect {
          put :update , id: active_script.id, :script => {name: nil}, :api_key=> account.api_key, :format => "json"
        }.to change {account.reload.scripts.size} .by(0)
        expect(response.body).to  eq("{\"errors\":{\"name\":[\"can't be blank\"]}}")
      end


    end

    describe "deleted" do

      it "should show deleted scripts" do
        active_script = create(:script, :account => account, :active => false)
        get :deleted, :api_key=> account.api_key, :format => "json"
        expect(JSON.parse(response.body).length).to eq(1)
      end
    end

    describe "restore" do

      it "should restore inactive campaign" do
        in_active_active_script = create(:script, :account => account, :active => false)
        put :restore, script_id: in_active_active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq("{\"message\":\"Script restored\"}")
      end
    end

    describe "questions_answered" do
      it "should return hash of question answer count" do
        active_script = create(:script, :account => account, :active => true)
        question = create(:question, :script => active_script)
        answer1 = create(:answer, :voter => create(:voter), campaign: create(:campaign), :possible_response => create(:possible_response), :question => question)
        get :questions_answered, id: active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq("{\"data\":{\"#{question.id}\":#{1}}}")
      end
    end

    describe "possible_responses_answered" do
      it "should return hash of possible response answer count" do
        active_script = create(:script, :account => account, :active => true)
        active_script1 = create(:script, :account => create(:account), :active => true)
        question = create(:question, :script => active_script)
        answer1 = create(:answer, :voter => create(:voter), campaign: create(:campaign), :possible_response => create(:possible_response), :question => question)
        get :possible_responses_answered, id: active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq("{\"data\":{}}")
      end
    end




  end

end
