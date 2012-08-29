require "spec_helper"

describe Client::ScriptsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }

  before(:each) do
    login_as(user)
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  it "lists voter fields to select" do
    script = Factory(:script, :account => account, :robo => false, :active => true)
    post :create, :script => script
    response.should be_success
    assigns[:voter_fields].should eq(Voter.upload_fields)
  end

  it "shows the list of voter fields which were selected" do
    script = Factory(:script, :account => account, :robo => false, :active => true)
    selected_voter_fields = ["CustomID", "FirstName", "MiddleName"]
    post :create, :script => script, :voter_field => selected_voter_fields
    response.should be_success
    assigns[:voter_field_values].should eq(selected_voter_fields)
  end

end
