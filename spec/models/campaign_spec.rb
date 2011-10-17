require "spec_helper"
require "#{RAILS_ROOT}/lib/twilio_lib"


describe "predictive_dialer" do

  it "does not dial when dials are already in progress" do
    campaign = Factory(:campaign, :calls_in_progress => true, :predictive_type => 'predictive')
    campaign.should_not_receive(:dial_predictive_voters)
    campaign.predictive_dial
  end

  it "does not dial when a campaign uses preview dialing" do
    campaign = Factory(:campaign, :calls_in_progress => false, :predictive_type => 'preview')
    campaign.should_not_receive(:dial_predictive_voters)
    campaign.predictive_dial
  end

  it "predictive dial dials voters" do
    campaign = Factory(:campaign, :calls_in_progress => false, :predictive_type => 'predictive')
    campaign.should_receive(:dial_predictive_voters)
    campaign.predictive_dial
  end

  it "set calls_in_progress before dialing predictive voters, and unsets it after" do
    campaign = Factory(:campaign, :calls_in_progress => false, :predictive_type => 'predictive')
    def campaign.dial_predictive_voters
      calls_in_progress.should == true
    end
    campaign.predictive_dial
    campaign.calls_in_progress.should == false
  end

  it "determines the campaign dial strategy" do
    Factory(:campaign, :predictive_type => 'predictive').should_not be_ratio_dial
    Factory(:campaign, :predictive_type => 'power_2').should be_ratio_dial
  end

  it "should determine the number of short calls to dial" do
    Factory(:campaign).determine_short_to_dial.should == 0
  end

  #it "should not add more short callers to the pool than the number of short calls to dial"

  it "should add idle callers to the dial pool" do
    campaign = Factory(:campaign)
    caller_session = Factory(:caller_session, :on_call => true, :available_for_call => true, :campaign => campaign)
    campaign.determine_pool_size(0).should == campaign.call_stats(10)[:dials_needed]
  end

  it "should add callers with calls over the long threshold to the dial pool"

  it "should properly choose the next voters to dial" do
    account = Factory(:account, :paid=>true)
    campaign = Factory(:campaign, :account => account, :caller_id => "12345", :caller_id_verified => true)
    campaign.caller_id_verified=true
    voter_list = Factory(:voter_list, :campaign => campaign, :active => true)
    voter = Factory(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
    campaign.choose_voters_to_dial(1).should == [voter]
  end

  it "excludes system blocked numbers" do
    account = Factory(:account, :paid => true)
    campaign = Factory(:campaign, :account => account, :caller_id => '12345')
    campaign.caller_id_verified=true
    voter_list = Factory(:voter_list, :campaign => campaign, :active => true)
    unblocked_voter = Factory(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
    blocked_voter = Factory(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
    Factory(:blocked_number, :number => blocked_voter.Phone, :account => account, :campaign=>nil)
    campaign.choose_voters_to_dial(10).should == [unblocked_voter]
  end

  it "excludes campaign blocked numbers" do
    account = Factory(:account, :paid => true)
    campaign = Factory(:campaign, :account => account, :caller_id => '12345')
    campaign.caller_id_verified=true
    voter_list = Factory(:voter_list, :campaign => campaign, :active => true)
    unblocked_voter = Factory(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
    blocked_voter = Factory(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
    Factory(:blocked_number, :number => blocked_voter.Phone, :account => account, :campaign=>campaign)
    Factory(:blocked_number, :number => unblocked_voter.Phone, :account => account, :campaign=>Factory(:campaign))
    campaign.choose_voters_to_dial(10).should == [unblocked_voter]
  end

  #canned scenarios where we back into / prove our new calls / max calls

end

describe "ratio_dialer" do
  it "should get the dial ratio based on predictive type"
  it "should set the dial ratio to 2 if no recent calls have been answered"
end


describe Campaign do

  it "restoring makes it active" do
    campaign = Factory(:campaign, :active => false)
    campaign.restore
    campaign.should be_active
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
    campaign = user.account.campaigns.create!
    campaign.name.should == 'Untitled 1'
    campaign = user.account.campaigns.create!
    campaign.name.should == 'Untitled 2'
  end

  it "doesn't overwrite a name that has been explicitly set" do
    user = Factory(:user)
    campaign = user.account.campaigns.create!(:name => 'Titled')
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

  it "returns campaigns using web ui" do
    campaign1 = Factory(:campaign, :use_web_ui => true)
    campaign2 = Factory(:campaign, :use_web_ui => false)
    Campaign.using_web_ui.should == [campaign1]
  end

  it "gives only active voter lists" do
    campaign = Factory(:campaign)
    active_voterlist = Factory(:voter_list, :campaign => campaign, :active => true)
    inactive_voterlist = Factory(:voter_list, :campaign => campaign, :active => false)
    campaign.voter_lists.should == [active_voterlist]
  end

  describe "campaigns with caller sessions that are on call" do
    let(:user) { Factory(:user) }
    let(:campaign) { Factory(:campaign, :account => user.account) }

    it "should give the campaign only once even if it has multiple caller sessions" do
      Factory(:caller_session, :campaign => campaign, :on_call => true)
      Factory(:caller_session, :campaign => campaign, :on_call => true)
      user.account.campaigns.with_running_caller_sessions.should == [campaign]
    end

    it "should not give campaigns without on_call caller sessions" do
      Factory(:caller_session, :campaign => campaign, :on_call => false)
      user.account.campaigns.with_running_caller_sessions.should be_empty
    end

    it "should not give another user's campaign'" do
      Factory(:caller_session, :campaign => Factory(:campaign, :account => Factory(:account)), :on_call => true)
      user.account.campaigns.with_running_caller_sessions.should be_empty
    end
  end

  describe 'lists campaigns' do
    before(:each) do
      @robo_campaign = Factory(:campaign, :robo => true)
      @manual_campaign = Factory(:campaign, :robo => false)
    end

    it "which are robo" do Campaign.robo.should == [@robo_campaign] end
    it "which are manual" do Campaign.manual.should == [@manual_campaign] end
  end

  describe "dialing" do
    it "dials its voter list" do
      campaign = Factory(:campaign)
      lists = 2.times.map{Factory(:voter_list, :campaign => campaign).tap{|list| list.should_receive(:dial)}}
      campaign.stub!(:voter_lists).and_return(lists)
      campaign.dial
    end

    it "dials only enabled voter lists" do
      campaign = Factory(:campaign)
      voter_list1 = Factory(:voter_list, :campaign => campaign)
      voter_list2 = Factory(:voter_list, :campaign => campaign, :enabled => false)
      voter_list1.should_receive(:dial)
      voter_list2.should_not_receive(:dial)
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

    it "does not start the dialer daemon for the campaign if the use has not already paid" do
      campaign = Factory(:campaign, :account => Factory(:account, :paid => false))
      campaign.start.should be_false
    end

    it "does not start the dialer daemon for the campaign if it is already started" do
      campaign = Factory(:campaign, :calls_in_progress => true)
      campaign.start.should be_false
    end

    it "starts the dialer daemon for the campaign if there are recordings to play" do
      script = Factory(:script)
      script.robo_recordings = [Factory(:robo_recording)]
      campaign = Factory(:campaign, :script => script, :account => Factory(:account, :paid => true))
      campaign.should_receive("system")
      campaign.start.should be_nil
    end

    it "does not start the dialer daemon for the campaign if its script has nothing to play" do
      script = Factory(:script)
      script.robo_recordings.size.should == 0
      campaign = Factory(:campaign, :script => script, :account => Factory(:account, :paid => true))
      campaign.start.should be_false
    end

    [true, false].each do |exit_status|
      it "reports the status if the daemon start success was #{exit_status}" do
        script = Factory(:script, :robo_recordings => [Factory(:robo_recording)])
        campaign = Factory(:campaign, :script => script, :calls_in_progress => false, :account => Factory(:account, :paid => true))
        campaign.stub(:system).and_return(exit_status)
        campaign.start.should eql(exit_status)
      end
    end

    it "stops the dialer daemon " do
      campaign = Factory(:campaign, :calls_in_progress => true)
      campaign.stop
      campaign.calls_in_progress.should be_false
    end

    it "lists the call attempts in progress" do
      campaign = Factory(:campaign)
      ended_call_attempt = Factory(:call_attempt, :call_end => 1.day.ago, :campaign => campaign)
      continuing_call_attempt_on_campaign = Factory(:call_attempt, :call_end => nil, :campaign => campaign)
      continuing_call_attempt_on_something_else = Factory(:call_attempt, :call_end => nil, :campaign => Factory(:campaign))
      campaign.call_attempts_in_progress.should == [continuing_call_attempt_on_campaign]
    end

    describe "number of dialed voters" do
      it "gives the number of dialed calls" do
        campaign = Factory(:campaign)
        lambda {
          call_attempt = Factory(:call_attempt, :campaign => campaign, :voter => Factory(:voter, :campaign => campaign))
        }.should change(campaign, :voters_dialed).by(1)
      end

      it "counts a number only once even if there are multiple attempts on it" do
        campaign = Factory(:campaign)
        voter = Factory(:voter, :campaign => campaign)
        lambda {
          call_attempt = Factory(:call_attempt, :campaign => campaign, :voter => voter)
        }.should change(campaign, :voters_dialed).by(1)
      end

      it "counts only the call attempts made on voters in the same campaign" do
        campaign1 = Factory(:campaign)
        campaign2 = Factory(:campaign)
        voter1 = Factory(:voter, :campaign => campaign1)
        voter2 = Factory(:voter, :campaign => campaign2)
        lambda {
          Factory(:call_attempt, :campaign => campaign1, :voter => voter1)
          Factory(:call_attempt, :campaign => campaign2, :voter => voter2)
        }.should change(campaign1, :voters_dialed).by(1)
      end
    end

    describe "number of remaining voters to be called" do
      it "gives the number of voters to be called" do
        campaign = Factory(:campaign)
        voter1 = Factory(:voter, :campaign => campaign)
        voter2 = Factory(:voter, :campaign => campaign)
        lambda {
          Factory(:call_attempt, :campaign => campaign, :voter => voter1)
        }.should change(campaign, :voters_remaining).by(-1)
      end

      it "counts a number only once even if there are multiple attempts on it" do
        campaign = Factory(:campaign)
        voter = Factory(:voter, :campaign => campaign)
        lambda {
          Factory(:call_attempt, :campaign => campaign, :voter => voter)
          Factory(:call_attempt, :campaign => campaign, :voter => voter)
        }.should change(campaign, :voters_remaining).by(-1)
      end
    end
  end

  it "clears calls" do
    campaign = Factory(:campaign)
    voters = 3.times.map{ Factory(:voter, :campaign => campaign, :result => 'foo', :status => 'bar') }
    voter_on_another_campaign = Factory(:voter, :result => 'hello', :status => 'world')
    campaign.clear_calls
    voters.each(&:reload).each do |voter|
      voter.result.should be_nil
      voter.status.should == 'not called'
    end
    voter_on_another_campaign.result.should == 'hello'
    voter_on_another_campaign.status.should == 'world'
  end
end
