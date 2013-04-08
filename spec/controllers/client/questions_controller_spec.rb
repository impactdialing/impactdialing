require "spec_helper"

describe Client::QuestionsController do
  let(:account) { Factory(:account, api_key: "abc123") }
  before(:each) do
    @user = Factory(:user, account_id: account.id)
  end



  describe "index" do
    it "should return questions for a script" do
      active_script = Factory(:script, :account => account, :active => true)
      question1 = Factory(:question, text: "abc", script_order: 1, script: active_script)
      question2 = Factory(:question, text: "def", script_order: 2, script: active_script)
      get :index, script_id: active_script.id, :api_key=> 'abc123', :format => "json"
      response.body.should eq("[#{question1.to_json},#{question2.to_json}]")
    end
  end

  describe "show" do
    it "should return question " do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      get :show, script_id: active_script.id, id: question.id,  :api_key=> 'abc123', :format => "json"
      response.body.should eq "{\"id\":#{question.id},\"text\":\"abc\",\"script_order\":1,\"external_id_field\":null,\"script_id\":#{active_script.id},\"possible_responses\":[]}"

    end

    it "should 404 if script not found" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      get :show, script_id: 100, id: question.id,  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end

    it "should 404 if question not found in script" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      get :show, script_id: active_script.id, id: 100,  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end


  end

  describe "destroy" do
    it "should delete question" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      delete :destroy, script_id: active_script.id, id: question.id,  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"message\":\"Question Deleted\",\"status\":\"ok\"}")
    end
  end

  describe "create" do
    it "should create question" do
      active_script = Factory(:script, :account => account, :active => true)
      post :create, script_id: active_script.id, question: {text: "Hi", script_order: 1},  :api_key=> 'abc123', :format => "json"
      response.body.should eq "{\"id\":#{active_script.questions.first.id},\"text\":\"Hi\",\"script_order\":1,\"external_id_field\":null,\"script_id\":#{active_script.id},\"possible_responses\":[]}"
      # response.body.should match(/{\"question\":{\"external_id_field\":null,\"id\":(.*),\"script_id\":#{active_script.id},\"script_order\":1,\"text\":\"Hi\"}}/)
    end

    it "should throw validation error" do
      active_script = Factory(:script, :account => account, :active => true)
      post :create, script_id: active_script.id, question: {text: "Hi"},  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"errors\":{\"script_order\":[\"can't be blank\",\"is not a number\"]}}")
    end

  end

  describe "update" do
    it "should update a question" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      put :update, script_id: active_script.id, id: question.id, question: {text: "Hi"},  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"message\":\"Question updated\"}")
      question.reload.text.should eq("Hi")
    end

    it "should throw validation error" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      put :update, script_id: active_script.id, id: question.id, question: {text: "Hi", script_order: nil},  :api_key=> 'abc123', :format => "json"
      response.body.should eq("{\"errors\":{\"script_order\":[\"can't be blank\",\"is not a number\"]}}")
    end

  end




end
