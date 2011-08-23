require "spec_helper"

describe Callers::CampaignsController do
  let(:caller) { Factory(:caller) }

  before(:each) do
    login_as(caller)
  end

  it "lists all active campaigns with a web ui" do
    caller.campaigns << Factory(:campaign, :active => false)
    caller.campaigns << Factory(:campaign, :active => false, :use_web_ui => true)
    caller.campaigns << Factory(:campaign, :active => true, :use_web_ui => false)
    campaign1 = Factory(:campaign, :active => true, :use_web_ui => true)
    caller.campaigns << campaign1
    caller.save
    get :index
    assigns(:campaigns).should == [campaign1]
  end

  it "finds a callers campaign" do
    caller.campaigns << Factory(:campaign, :active => false)
    campaign1 = Factory(:campaign, :active => true, :use_web_ui => true)
    caller.campaigns << campaign1
    caller.save
    get :show, :id => campaign1.id
    assigns(:campaign).should == campaign1
  end


end
