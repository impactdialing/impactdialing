require "spec_helper"

describe Client::ScriptsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }

  before(:each) do
    login_as(user)
  end

  it "deletes a script" do
    script = Factory(:script, :account=> account, :robo => false, :active => true)
    delete :destroy, :id => script.id
    script.reload.should_not be_active
  end
  
end
