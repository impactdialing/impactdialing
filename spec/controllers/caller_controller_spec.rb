require "spec_helper"

describe CallerController do
  describe 'index' do
    it "doesn't list deleted campaigns" do
      caller = Factory(:caller)
      caller.campaigns << Factory(:campaign, :active => false)
      caller.campaigns << Factory(:campaign, :active => true)
      caller.save!
      login_as(caller)
      get :index
      assigns(:campaigns).should have(1).thing
      assigns(:campaigns)[0].should be_active
    end
  end
end
