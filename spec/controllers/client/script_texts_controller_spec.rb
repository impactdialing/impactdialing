require "spec_helper"

describe Client::ScriptTextsController do
  let(:account) { Factory(:account, api_key: "abc123") }
  before(:each) do
    @user = Factory(:user, account_id: account.id)
  end

  
  
  describe "index" do
    it "should return texts for a script" do
      active_script = Factory(:script, :account => account, :active => true)
      script_text1 = Factory(:script_text, content: "abc", script_order: 1, script: active_script)
      script_text2 = Factory(:script_text, content: "def", script_order: 2, script: active_script)
      get :index, script_id: active_script.id, :api_key=> 'abc123', :format => "json"
      response.body.should eq("[#{script_text1.to_json},#{script_text2.to_json}]")
    end
  end
  
  describe "show" do
    it "should return script text" do
      active_script = Factory(:script, :account => account, :active => true)
      script_text = Factory(:script_text, content: "abc", script_order: 1, script: active_script)
      Factory(:script_text, content: "def", script_order: 2, script: active_script)
      get :show, script_id: active_script.id, id: script_text.id,  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"script_text\":{\"content\":\"abc\",\"id\":#{script_text.id},\"script_id\":#{active_script.id},\"script_order\":1}}")
    end
    
    it "should 404 if script not found" do
      active_script = Factory(:script, :account => account, :active => true)
      script_text = Factory(:script_text, content: "abc", script_order: 1, script: active_script)
      Factory(:script_text, content: "def", script_order: 2, script: active_script)
      get :show, script_id: 100, id: script_text.id,  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end
    
    it "should 404 if script text not found in script" do
      active_script = Factory(:script, :account => account, :active => true)
      script_text = Factory(:script_text, content: "abc", script_order: 1, script: active_script)
      Factory(:script_text, content: "def", script_order: 2, script: active_script)
      get :show, script_id: active_script.id, id: 100,  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end
    
    
  end
  
  describe "destroy" do
    it "should delete script text" do
      active_script = Factory(:script, :account => account, :active => true)
      script_text = Factory(:script_text, content: "abc", script_order: 1, script: active_script)
      Factory(:script_text, content: "def", script_order: 2, script: active_script)
      delete :destroy, script_id: active_script.id, id: script_text.id,  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"message\":\"Script Text Deleted\",\"status\":\"ok\"}")
    end
  end
  
  describe "create" do
    it "should create script text" do
      active_script = Factory(:script, :account => account, :active => true)
      Factory(:script_text, content: "def", script_order: 2, script: active_script)
      post :create, script_id: active_script.id, script_text: {content: "Hi", script_order: 1},  :api_key=> 'abc123', :format => "json"
      response.body.should match(/{\"script_text\":{\"content\":\"Hi\",\"id\":(.*),\"script_id\":#{active_script.id},\"script_order\":1}}/)
    end
    
    it "should throw validation error" do
      active_script = Factory(:script, :account => account, :active => true)
      Factory(:script_text, content: "def", script_order: 2, script: active_script)
      post :create, script_id: active_script.id, script_text: {content: "Hi"},  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"errors\":{\"script_order\":[\"can't be blank\",\"is not a number\"]}}")
    end
    
  end
  
  describe "update" do
    it "should update script text" do
      active_script = Factory(:script, :account => account, :active => true)
      script_text = Factory(:script_text, content: "abc", script_order: 1, script: active_script)
      Factory(:script_text, content: "def", script_order: 2, script: active_script)
      put :update, script_id: active_script.id, id: script_text.id, script_text: {content: "Hi"},  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"message\":\"Script Text updated\"}")
    end
    
    it "should throw validation error" do
      active_script = Factory(:script, :account => account, :active => true)
      script_text = Factory(:script_text, content: "abc", script_order: 1, script: active_script)
      Factory(:script_text, content: "def", script_order: 2, script: active_script)
      put :update, script_id: active_script.id, id: script_text.id, script_text: {content: "Hi", script_order: nil},  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"errors\":{\"script_order\":[\"can't be blank\",\"is not a number\"]}}")
    end
    
  end
  
  
  
  
end
