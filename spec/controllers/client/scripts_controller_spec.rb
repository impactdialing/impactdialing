require 'rails_helper'

describe Client::ScriptsController, :type => :controller do
  describe "html/json formats" do

    let(:question) { build(:question) }
    let(:script) { create(:script) }
    let(:json_params) { {:id => script.id, :format => :json} }
    let(:html_params) { json_params.merge({:format => :html}) }
    let(:current_template) { { data: {} }.to_json }

    before do
      allow(controller).to receive(:check_login) { true }
      allow(controller).to receive(:check_tos_accepted) { true }
    end

    context 'when user role is admin' do
      let(:admin) { create(:user, {account: script.account}) }

      before do
        allow(controller).to receive(:current_user) { admin }
      end

      describe '#index' do
        it 'allows admin access' do
          get(:index, html_params)
          expect(response).to render_template 'index'
        end
      end

      describe '#show' do
        it 'allows admin access' do
          get(:show, html_params)
          expect(response).to redirect_to edit_client_script_path
        end
      end

      describe '#edit' do
        it 'allows admin access' do
          get(:edit, html_params)
          expect(response).to render_template 'edit'
        end
      end

      describe '#new' do
        it 'allows admin access' do
          get(:new, html_params)
          expect(response).to render_template 'new'
        end
      end

      describe '#create' do
        let(:selected_voter_fields) { ["phone", "custom_id", "last_name", "first_name"] }
        it 'shows the list of selected voter fields' do
          post(:create, script: {name: "script1"}, voter_field: selected_voter_fields)
          expect(Script.find_by_name("script1").voter_fields).to eq(selected_voter_fields.to_json)
        end
        it 'redirects to client scripts' do
          post(:create, script: {name: "script1"}, voter_field: selected_voter_fields)
          expect(response).to redirect_to client_scripts_path
        end
      end

      describe '#update' do
        it 'allows admin access' do
          patch(:update, html_params.merge(script: {name: "script2"}))
          expect(response).to redirect_to client_scripts_path
        end
        it 'updates the script' do
          patch(:update, html_params.merge(script: {name: "script2"}))
          expect(script.reload.name).to eq "script2"
        end
      end

      describe '#destroy' do
        it 'allows admin access' do
          delete(:destroy, html_params)
          expect(response).to redirect_to client_scripts_path
        end
      end

      describe '#questions_answered' do
        it 'allows admin access' do
          get(:questions_answered, json_params)
          expect(response.body).to eq current_template
        end
      end

      describe '#possible_responses_answered' do
        it 'allows admin access' do
          get(:possible_responses_answered, json_params)
          expect(response.body).to eq current_template
        end
      end

      describe '#archived' do
        it 'allows admin access' do
          get(:archived, html_params)
          expect(response).to render_template "archived"
        end
      end

      describe '#restore' do
        it 'allows admin access' do
          patch(:restore, html_params)
          expect(response.body).to redirect_to client_scripts_path
        end
      end
    end

    context 'when user role is supervisor' do
      let(:supervisor){ create(:user, {role: 'supervisor', account: script.account}) }

      before do
        allow(controller).to receive(:current_user) { supervisor }
      end

      describe 'html params' do
        after do
          expect(response).to redirect_to root_url
        end

        describe '#index' do
          it 'disallows supervisor access' do
            get(:index, html_params)
          end
        end

        describe '#show' do
          it 'disallows supervisor access' do
            get(:show, html_params)
          end
        end

        describe '#edit' do
          it 'disallows supervisor access' do
            get(:edit, html_params)
            expect(response).to redirect_to root_url
          end
        end

        describe '#new' do
          it 'disallows supervisor access' do
            get(:new, html_params)
            expect(response).to redirect_to root_url
          end
        end

        describe '#create' do
          let(:selected_voter_fields) { ["phone", "custom_id", "last_name", "first_name"] }
          it 'disallows supervisor access' do
            post(:create, script: {name: "script1"}, voter_field: selected_voter_fields)
            expect(response).to redirect_to root_url
          end
        end

        describe '#archived' do
          it 'disallows supervisor access' do
            patch(:archived, html_params)
            expect(response).to redirect_to root_url
          end
        end

        describe '#restore' do
          it 'disallows supervisor access' do
            patch(:restore, html_params)
            expect(response).to redirect_to root_url
          end
        end
      end

      describe 'json params' do
        after do
          expect(response.body).to include I18n.t(:admin_access)
        end
        describe '#questions_answered' do
          it 'disallows supervisor access' do
            get(:questions_answered, json_params)
          end
        end

        describe '#possible_responses_answered' do
          it 'disallows supervisor access' do
            get(:possible_responses_answered, json_params)
          end
        end
      end
    end
  end


  describe "api" do
    let(:account) { create(:account) }
    let(:user) { create(:user, :account => account) }

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

        expect(response.body).to eq(active_script.reload.to_json)
      end
    end

    describe "edit" do
      it "should show script" do
        active_script = create(:script, :account => account, :active => true)
        script_text = create(:script_text, script_order: 1, script: active_script)
        get :edit, id: active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq(active_script.reload.to_json)
      end
    end

    describe "destroy" do
      it "should delete script" do
        active_script = create(:script, :account => account, :active => true)
        delete :destroy, :id=> active_script.id, :api_key=> account.api_key, :format => "json"
        expect(response.body).to eq("{\"message\":\"Script archived\"}")
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
        expect(response.body).to eq("{\"errors\":{\"base\":[\"This script cannot be archived, as it is currently assigned to an active campaign.\"]}}")
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

    describe "archived" do
      it "should show archived scripts" do
        active_script = create(:script, :account => account, :active => false)
        get :archived, :api_key=> account.api_key, :format => "json"
        expect(JSON.parse(response.body).length).to eq(1)
      end
    end

    describe "restore" do
      it "should restore inactive campaign" do
        in_active_active_script = create(:script, :account => account, :active => false)
        put :restore, id: in_active_active_script.id, :api_key=> account.api_key, :format => "json"
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
