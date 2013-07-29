require "spec_helper"

describe Client::NotesController do
  let(:account) { create(:account) }
  before(:each) do
    @user = create(:user, account_id: account.id)
  end



  describe "index" do
    it "should return notes for a script" do
      active_script = create(:script, :account => account, :active => true)
      note1 = create(:note, note: "abc", script_order: 1, script: active_script)
      note2 = create(:note, note: "def", script_order: 2, script: active_script)
      get :index, script_id: active_script.id, :api_key=> account.api_key, :format => "json"
      response.body.should eq("[#{note1.to_json},#{note2.to_json}]")
    end
  end

  describe "show" do
    it "should return note " do
      active_script = create(:script, :account => account, :active => true)
      note = create(:note, note: "abc", script_order: 1, script: active_script)
      create(:note, note: "def", script_order: 2, script: active_script)
      get :show, script_id: active_script.id, id: note.id,  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"note\":{\"id\":#{note.id},\"note\":\"abc\",\"script_id\":#{active_script.id},\"script_order\":1}}")
    end

    it "should 404 if script not found" do
      active_script = create(:script, :account => account, :active => true)
      note = create(:note, note: "abc", script_order: 1, script: active_script)
      get :show, script_id: 100, id: note.id,  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end

    it "should 404 if note not found in script" do
      active_script = create(:script, :account => account, :active => true)
      note = create(:note, note: "abc", script_order: 1, script: active_script)
      create(:note, note: "def", script_order: 2, script: active_script)
      get :show, script_id: active_script.id, id: 100,  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Resource not found\"}")
    end


  end

  describe "destroy" do
    it "should delete note" do
      active_script = create(:script, :account => account, :active => true)
      note = create(:note, note: "abc", script_order: 1, script: active_script)
      delete :destroy, script_id: active_script.id, id: note.id,  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Note Deleted\",\"status\":\"ok\"}")
    end
  end

  describe "create" do
    it "should create note" do
      active_script = create(:script, :account => account, :active => true)
      post :create, script_id: active_script.id, note: {note: "Hi", script_order: 1},  :api_key=> account.api_key, :format => "json"
      response.body.should match(/{\"note\":{\"id\":(.*),\"note\":\"Hi\",\"script_id\":#{active_script.id},\"script_order\":1}}/)
    end

    it "should throw validation error" do
      active_script = create(:script, :account => account, :active => true)
      post :create, script_id: active_script.id, note: {note: "Hi"},  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"errors\":{\"script_order\":[\"can't be blank\",\"is not a number\"]}}")
    end

  end

  describe "update" do
    it "should update a note" do
      active_script = create(:script, :account => account, :active => true)
      note = create(:note, note: "abc", script_order: 1, script: active_script)
      put :update, script_id: active_script.id, id: note.id, note: {note: "Hi"},  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"message\":\"Note updated\"}")
      note.reload.note.should eq("Hi")
    end

    it "should throw validation error" do
      active_script = create(:script, :account => account, :active => true)
      note = create(:note, note: "abc", script_order: 1, script: active_script)
      put :update, script_id: active_script.id, id: note.id, note: {note: "Hi", script_order: nil},  :api_key=> account.api_key, :format => "json"
      response.body.should eq("{\"errors\":{\"script_order\":[\"can't be blank\",\"is not a number\"]}}")
    end

  end




end
