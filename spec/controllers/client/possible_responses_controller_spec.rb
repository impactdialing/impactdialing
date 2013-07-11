require "spec_helper"

describe Client::PossibleResponsesController do
  let(:account) { Factory(:account) }
  before(:each) do
    @user = Factory(:user, account_id: account.id)
  end



  describe "index" do
    it "should return possible responses for a question" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, :script => active_script)
      possible_response1 = Factory(:possible_response, question_id: question.id)
      possible_response2 = Factory(:possible_response, question_id: question.id)
      get :index, script_id: active_script.id, question_id: question.id, :api_key=> account.api_key, :format => "json"
      response.body.should eq("[#{possible_response1.to_json},#{possible_response2.to_json}]")
    end
  end

  describe "show" do
    it "should return possible response " do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, :script => active_script)
      possible_response = Factory(:possible_response, question_id: question.id)
      get :show, script_id: active_script.id, question_id: question.id, id: possible_response.id, :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"possible_response\":{\"external_id_field\":null,\"id\":#{possible_response.id},\"keypad\":null,\"possible_response_order\":1,\"question_id\":#{question.id},\"retry\":false,\"value\":\"no_response\"}}")
    end

    it "should 404 if script not found" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, :script => active_script)
      possible_response = Factory(:possible_response, question_id: question.id)
      get :show, script_id: 100, question_id: question.id, id: possible_response.id, :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end

    it "should 404 if question not found in script" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, :script => active_script)
      possible_response = Factory(:possible_response, question_id: question.id)
      get :show, script_id: active_script.id, question_id: 100, id: possible_response.id, :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end

    it "should 404 if possible response not found in script" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, :script => active_script)
      possible_response = Factory(:possible_response, question_id: question.id)
      get :show, script_id: active_script.id, question_id: question.id, id: 100, :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end

  end

  describe "destroy" do
    it "should delete possible response" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      possible_response = Factory(:possible_response, question_id: question.id)
      delete :destroy, script_id: active_script.id, question_id: question.id, id: possible_response.id,  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Possible Response Deleted\",\"status\":\"ok\"}")
    end
  end

  describe "create" do
    it "should create possible response" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      post :create, script_id: active_script.id, question_id: question.id, possible_response: {value: "Hi", possible_response_order: 1},  :api_key=> account.api_key, :format => "json"
      response.body.should match(/{\"possible_response\":{\"external_id_field\":null,\"id\":(.*),\"keypad\":null,\"possible_response_order\":1,\"question_id\":#{question.id},\"retry\":false,\"value\":\"Hi\"}}/)
    end

    it "should throw validation error" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      post :create, script_id: active_script.id, question_id: question.id, possible_response: {value: nil, possible_response_order: 1},  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"errors\":{\"value\":[\"can't be blank\"]}}")
    end

  end

  describe "update" do
    it "should update possible response value" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      possible_response = Factory(:possible_response, question_id: question.id)
      put :update, script_id: active_script.id, question_id: question.id, id: possible_response.id, possible_response: {value: "Hi"},  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Possible Response updated\"}")
      possible_response.reload.value.should eq("Hi")
    end

    it "should throw validation error" do
      active_script = Factory(:script, :account => account, :active => true)
      question = Factory(:question, text: "abc", script_order: 1, script: active_script)
      possible_response = Factory(:possible_response, question_id: question.id)
      put :update, script_id: active_script.id, question_id: question.id, id: possible_response.id, possible_response: {value: nil},  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"errors\":{\"value\":[\"can't be blank\"]}}")
    end

  end




end
