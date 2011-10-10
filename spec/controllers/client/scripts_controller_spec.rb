require "spec_helper"

describe Client::ScriptsController do
  let(:user){ Factory(:user)}

  before(:each) do
    login_as(user)
  end

  it "deletes a script" do
    script = Factory(:script, :user=> user, :robo => false, :active => true)
    delete :destroy, :id => script.id
    script.reload.should_not be_active
  end
end
