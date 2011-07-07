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
    older_campaign = Factory(:campaign).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
    newer_campaign = Factory(:campaign).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
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

  it "should return active campaigns" do
    campaign1 = Factory(:campaign)
    campaign2 = Factory(:campaign)
    campaign3 = Factory(:campaign, :active => false)

    Campaign.active.should == [campaign1, campaign2]
  end

  it "gives only active voter lists" do
    campaign = Factory(:campaign)
    active_voterlist = Factory(:voter_list, :campaign => campaign, :active => true)
    inactive_voterlist = Factory(:voter_list, :campaign => campaign, :active => false)
    campaign.voter_lists.should == [active_voterlist]
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

    it "sets the calls in progress flag when it starts dialing" do
      Campaign.send(:define_method,:dial_voters) do
        self.calls_in_progress?.should == true
      end
      campaign = Factory(:campaign)
      campaign.dial
      campaign.calls_in_progress.should == false
    end

    it "starts the dialer daemon for the campaign if it is not running" do
      campaign = Factory(:campaign, :calls_in_progress => false)
      campaign.start.should be_true
    end

    it "does not start the dialer daemon for the campaign if it is already started" do
      campaign = Factory(:campaign, :calls_in_progress => true)
      campaign.start.should be_false
    end

    it "stops the dialer daemon " do
      campaign = Factory(:campaign, :calls_in_progress => true)
      campaign.stop
      campaign.calls_in_progress.should be_false
    end

    describe "number of dialed voters" do
      it "gives the number of dialed calls" do
        campaign = Factory(:campaign)
        lambda {
          call_attempt = Factory(:call_attempt, :campaign => campaign, :voter => Factory(:voter, :campaign => campaign))
        }.should change {
          campaign.voters_dialed
        }.by(1)
      end

      it "counts a number only once even if there are multiple attempts on it" do
        campaign = Factory(:campaign)
        voter = Factory(:voter, :campaign => campaign)
        lambda {
          call_attempt = Factory(:call_attempt, :campaign => campaign, :voter => voter)
        }.should change {
          campaign.voters_dialed
        }.by(1)
      end

      it "counts only the call attempts made on voters in the same campaign" do
        campaign1 = Factory(:campaign)
        campaign2 = Factory(:campaign)
        voter1 = Factory(:voter, :campaign => campaign1)
        voter2 = Factory(:voter, :campaign => campaign2)
        lambda {
          Factory(:call_attempt, :campaign => campaign1, :voter => voter1)
          Factory(:call_attempt, :campaign => campaign2, :voter => voter2)
        }.should change {
          campaign1.voters_dialed
        }.by(1)
      end
    end

    describe "number of remaining voters to be called" do
      it "gives the number of voters to be called" do
        campaign = Factory(:campaign)
        voter1 = Factory(:voter, :campaign => campaign)
        voter2 = Factory(:voter, :campaign => campaign)
        lambda {
          Factory(:call_attempt, :campaign => campaign, :voter => voter1)
        }.should change {
          campaign.voters_remaining
        }.by(-1)
      end

      it "counts a number only once even if there are multiple attempts on it" do
        campaign = Factory(:campaign)
        voter = Factory(:voter, :campaign => campaign)
        lambda {
          Factory(:call_attempt, :campaign => campaign, :voter => voter)
          Factory(:call_attempt, :campaign => campaign, :voter => voter)
        }.should change {
          campaign.voters_remaining
        }.by(-1)
      end
    end
  end
end
