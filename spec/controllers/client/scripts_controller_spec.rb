require "spec_helper"

describe Client::ScriptsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }

  before(:each) do
    login_as(user)
    request.env['HTTP_REFERER'] = 'http://referer'
  end

  it "deletes a script" do
    script = Factory(:script, :account=> account, :robo => false, :active => true)
    delete :destroy, :id => script.id
    script.reload.should_not be_active
  end
  
  it "should not delete a script if assigned to an active campaign" do
    script = Factory(:script, account: account, robo: false, active: true)
    campaign =  Factory(:preview, active: true, script_id: script.id, account: account)
    delete :destroy, :id => script.id
    script.reload.should be_active
  end
  
  it "should  delete a script if assigned to an inactive campaign" do
    script = Factory(:script, account: account, robo: false, active: true)
    campaign =  Factory(:predictive, active: false, script_id: script.id, account: account)
    delete :destroy, :id => script.id
    script.reload.should_not be_active
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
