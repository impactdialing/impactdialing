require "spec_helper"

describe Callers::CampaignsController do
  let(:account) { Factory(:account) }
  let(:user) { Factory(:user, :account => account) }
  let(:campaign) { Factory(:predictive, :account => account) }
  let(:caller) { Factory(:caller, :account => account, :campaign => campaign) }


  before(:each) do
    login_as(caller)
  end

  it "finds a callers campaign" do
    campaign1 = Factory(:predictive, :active => true,)
    caller_session = Factory(:caller_session, caller: caller)
    get :show, id:  campaign1.id, caller_session: caller_session
    assigns(:campaign).should == campaign
  end

end
