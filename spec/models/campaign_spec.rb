require "spec_helper"

describe Campaign do
  include ActionController::TestProcess

  it "restoring makes it active" do
    campaign = Factory(:campaign, :active => false)
    campaign.restore
    campaign.active?.should == true
  end

  it "sorts by the updated date" do
    Campaign.record_timestamps = false
    older_campaign             = Factory(:campaign).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
    newer_campaign             = Factory(:campaign).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
    Campaign.record_timestamps = true
    Campaign.by_updated.all.should == [newer_campaign, older_campaign]
  end

  it "lists deleted campaigns" do
    deleted_campaign = Factory(:campaign, :active => false)
    other_campaign = Factory(:campaign, :active => true)
    Campaign.deleted.should == [deleted_campaign]
  end

  it "generates its own name if one isn't provided" do
    user = Factory(:user)
    campaign = user.campaigns.create!
    campaign.name.should == 'Untitled 1'
    campaign = user.campaigns.create!
    campaign.name.should == 'Untitled 2'
  end

  it "doesn't overwrite a name that has been explicitly set" do
    user = Factory(:user)
    campaign = user.campaigns.create!(:name => 'Titled')
    campaign.name.should == 'Titled'
  end

  it "should not invoke Twilio if caller id is not present" do
    TwilioLib.should_not_receive(:new)
    campaign = Factory(:campaign)
    campaign.caller_id = nil
    campaign.save
  end

  describe "campaigns with caller sessions that are on call" do
    let(:user) { Factory(:user) }
    let(:campaign) { Factory(:campaign, :user => user) }

    it "should give the campaign only once even if it has multiple caller sessions" do
      Factory(:caller_session, :campaign => campaign, :on_call => true)
      Factory(:caller_session, :campaign => campaign, :on_call => true)
      user.campaigns.with_running_caller_sessions.should == [campaign]
    end

    it "should not give campaigns without on_call caller sessions" do
      Factory(:caller_session, :campaign => campaign, :on_call => false)
      user.campaigns.with_running_caller_sessions.should be_empty
    end

    it "should not give another user's campaign'" do
      Factory(:caller_session, :campaign => Factory(:campaign, :user => Factory(:user)), :on_call => true)
      user.campaigns.with_running_caller_sessions.should be_empty
    end
  end

  describe 'lists campaigns' do
    before(:each) do
      @robo_campaign = Factory(:campaign, :robo => true)
      @manual_campaign = Factory(:campaign, :robo => false)
    end

    it "which are robo" do
      Campaign.robo.should == [@robo_campaign]
    end

    it "which are manual" do
      Campaign.manual.should == [@manual_campaign]
    end
  end

  describe "dialing" do
    it "dials its voter list" do
      campaign = Factory(:campaign)
      voter_list1 = Factory(:voter_list, :campaign => campaign)
      voter_list2 = Factory(:voter_list, :campaign => campaign)
      voter_list1.should_receive(:dial)
      voter_list2.should_receive(:dial)
      campaign.stub!(:voter_lists).and_return([voter_list1, voter_list2])
      campaign.dial
    end
  end
end
