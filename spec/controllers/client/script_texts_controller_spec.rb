require "spec_helper"

describe Client::ScriptTextsController, :type => :controller do
  let(:account) { create(:account) }
  before(:each) do
    @user = create(:user, account_id: account.id)
  end



  describe "index" do
    it "should return texts for a script" do
      active_script = create(:script, :account => account, :active => true)
      script_text1 = create(:script_text, content: "abc", script_order: 1, script: active_script)
      script_text2 = create(:script_text, content: "def", script_order: 2, script: active_script)
      get :index, script_id: active_script.id, :api_key=> account.api_key, :format => "json"
      expect(response.body).to eq("[#{script_text1.to_json},#{script_text2.to_json}]")
    end
  end

  describe "show" do
    it "should return script text" do
      active_script = create(:script, :account => account, :active => true)
      script_text = create(:script_text, content: "abc", script_order: 1, script: active_script)
      create(:script_text, content: "def", script_order: 2, script: active_script)
      get :show, script_id: active_script.id, id: script_text.id,  :api_key=> account.api_key, :format => "json"
      expect(response.body).to eq("{\"script_text\":{\"content\":\"abc\",\"id\":#{script_text.id},\"script_id\":#{active_script.id},\"script_order\":1,\"markdown_content\":\"\\n<p>abc</p>\\n\"}}")
    end

    it "should 404 if script not found" do
      active_script = create(:script, :account => account, :active => true)
      script_text = create(:script_text, content: "abc", script_order: 1, script: active_script)
      create(:script_text, content: "def", script_order: 2, script: active_script)
      get :show, script_id: 100, id: script_text.id,  :api_key=> account.api_key, :format => "json"
      expect(response.body).to eq("{\"message\":\"Resource not found\"}")
    end

    it "should 404 if script text not found in script" do
      active_script = create(:script, :account => account, :active => true)
      script_text = create(:script_text, content: "abc", script_order: 1, script: active_script)
      create(:script_text, content: "def", script_order: 2, script: active_script)
      get :show, script_id: active_script.id, id: 100,  :api_key=> account.api_key, :format => "json"
      expect(response.body).to eq("{\"message\":\"Resource not found\"}")
    end


  end

  describe "destroy" do
    it "should delete script text" do
      active_script = create(:script, :account => account, :active => true)
      script_text = create(:script_text, content: "abc", script_order: 1, script: active_script)
      create(:script_text, content: "def", script_order: 2, script: active_script)
      delete :destroy, script_id: active_script.id, id: script_text.id,  :api_key=> account.api_key, :format => "json"
      expect(response.body).to eq("{\"message\":\"Script Text Deleted\",\"status\":\"ok\"}")
    end
  end

  describe "create" do
    it "should create script text" do
      active_script = create(:script, :account => account, :active => true)
      create(:script_text, content: "def", script_order: 2, script: active_script)
      post :create, script_id: active_script.id, script_text: {content: "Hi", script_order: 1},  :api_key=> account.api_key, :format => "json"
      expect(response.body).to match(/{\"script_text\":{\"content\":\"Hi\",\"id\":(.*),\"script_id\":#{active_script.id},\"script_order\":1,\"markdown_content\":\"\\n<p>Hi<\/p>\\n\"}}/)
    end

    it "should throw validation error" do
      active_script = create(:script, :account => account, :active => true)
      create(:script_text, content: "def", script_order: 2, script: active_script)
      post :create, script_id: active_script.id, script_text: {content: "Hi"},  :api_key=> account.api_key, :format => "json"
      expect(response.body).to eq("{\"errors\":{\"script_order\":[\"can't be blank\",\"is not a number\"]}}")
    end

  end

  describe "update" do
    it "should update script text" do
      active_script = create(:script, :account => account, :active => true)
      script_text = create(:script_text, content: "abc", script_order: 1, script: active_script)
      create(:script_text, content: "def", script_order: 2, script: active_script)
      put :update, script_id: active_script.id, id: script_text.id, script_text: {content: "Hi"},  :api_key=> account.api_key, :format => "json"
      expect(response.body).to eq("{\"message\":\"Script Text updated\"}")
    end

    it "should throw validation error" do
      active_script = create(:script, :account => account, :active => true)
      script_text = create(:script_text, content: "abc", script_order: 1, script: active_script)
      create(:script_text, content: "def", script_order: 2, script: active_script)
      put :update, script_id: active_script.id, id: script_text.id, script_text: {content: "Hi", script_order: nil},  :api_key=> account.api_key, :format => "json"
      expect(response.body).to eq("{\"errors\":{\"script_order\":[\"can't be blank\",\"is not a number\"]}}")
    end

  end




end
