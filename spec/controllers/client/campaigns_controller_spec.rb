require "spec_helper"

describe Client::CampaignsController do
  let(:campaign) { Factory(:campaign) }
  let(:user) { Factory(:user) }

  before(:each) do
    login_as user
  end

  it "clears calls" do
    voter = Factory(:voter, :campaign => campaign, :result => 'foo', :status => 'bar')
    put :clear_calls, :campaign_id => campaign.id
    voter.reload
    voter.result.should be_nil
    voter.status.should == 'not called'
    response.should redirect_to(:back)
  end
end
