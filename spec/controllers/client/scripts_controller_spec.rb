require "spec_helper"

describe Client::ScriptsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }

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
    script = Factory(:script, :account => account, :robo => false, :active => true)
    selected_voter_fields = ["Phone", "CustomID", "LastName", "FirstName"]
    post :create, script: {name: "script1"}, voter_field: selected_voter_fields
    response.should redirect_to(client_scripts_url)
    Script.find_by_name("script1").voter_fields.should eq(selected_voter_fields.to_json)
  end

end
