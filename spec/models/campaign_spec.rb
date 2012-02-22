require "spec_helper"
require Rails.root.join("lib/twilio_lib")

describe "predictive_dialer" do


  it "predictive dial dials voters" do
     campaign = Factory(:campaign, :calls_in_progress => false, :predictive_type => 'predictive')
     campaign.should_receive(:dial_predictive_voters)
     campaign.predictive_dial
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
     account = Factory(:account, :activated => true)
     campaign = Factory(:campaign, :account => account, :caller_id => "0123456789", :caller_id_verified => true)
     campaign.caller_id_verified=true
     voter_list = Factory(:voter_list, :campaign => campaign, :active => true)
     voter = Factory(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
     campaign.choose_voters_to_dial(1).should == [voter]
   end

  it "dials voters off enabled lists only" do
     campaign = Factory(:campaign)
     enabled_list = Factory(:voter_list, :campaign => campaign, :active => true, :enabled => true)
     disabled_list = Factory(:voter_list, :campaign => campaign, :active => true, :enabled => false)
     voter1 = Factory(:voter, :campaign => campaign, :voter_list => enabled_list)
     voter2 = Factory(:voter, :campaign => campaign, :voter_list => disabled_list)
     campaign.choose_voters_to_dial(2).should == [voter1]
  end

   it "should  choose priority voter as the next voters to dial" do
     account = Factory(:account, :activated => true)
     campaign = Factory(:campaign, :account => account, :caller_id => "0123456789", :caller_id_verified => true)
     campaign.caller_id_verified=true
     voter_list = Factory(:voter_list, :campaign => campaign, :active => true)
     voter = Factory(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account)
     priority_voter = Factory(:voter, :campaign => campaign, :status=>"not called", :voter_list => voter_list, :account => account, priority: "1")
     campaign.choose_voters_to_dial(1).should == [priority_voter]
   end


   it "excludes system blocked numbers" do
     account = Factory(:account, :activated => true)
     campaign = Factory(:campaign, :account => account)
     campaign.caller_id_verified=true
     voter_list = Factory(:voter_list, :campaign => campaign, :active => true)
     unblocked_voter = Factory(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
     blocked_voter = Factory(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
     Factory(:blocked_number, :number => blocked_voter.Phone, :account => account, :campaign=>nil)
     campaign.choose_voters_to_dial(10).should == [unblocked_voter]
   end

   it "excludes campaign blocked numbers" do
     account = Factory(:account, :activated => true)
     campaign = Factory(:campaign, :account => account)
     campaign.caller_id_verified=true
     voter_list = Factory(:voter_list, :campaign => campaign, :active => true)
     unblocked_voter = Factory(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
     blocked_voter = Factory(:voter, :campaign => campaign, :status => 'not called', :voter_list => voter_list, :account => account)
     Factory(:blocked_number, :number => blocked_voter.Phone, :account => account, :campaign=>campaign)
     Factory(:blocked_number, :number => unblocked_voter.Phone, :account => account, :campaign=>Factory(:campaign))
     campaign.choose_voters_to_dial(10).should == [unblocked_voter]
   end

   it "should return zero voters, if active_voter_list_ids is empty" do
     campaign = Factory(:campaign, :account => Factory(:account, :activated => true))
     VoterList.should_receive(:active_voter_list_ids).with(campaign.id).and_return([])
     campaign.voters("not called").should == []
   end

   it "should return voters to be call" do
     campaign = Factory(:campaign, :account => Factory(:account, :activated => true), recycle_rate: 3)
     VoterList.should_receive(:active_voter_list_ids).with(campaign.id).and_return([12, 123])
     Voter.should_receive(:to_be_called).with(campaign.id, [12, 123], "not called", 3).and_return(["v1", "v2", "v3", "v2"])
     Voter.should_not_receive(:just_called_voters_call_back).with(campaign.id, [12, 123])
     campaign.voters("not called").length.should == 3
   end

   describe "power dialing" do
     let(:campaign) { Factory(:campaign, :predictive_type => "power_2") }

     def setup_callers
       3.times { Factory(:caller_session, :caller => Factory(:caller), :campaign => campaign, :available_for_call => true, :on_call => true) }
     end

     def setup_voters
       10.times { Factory(:voter, :campaign => campaign, :status => Voter::Status::NOTCALLED) }
     end

     it "should determine dial ratio" do
       campaign.ratio_dial?.should be_true
       campaign.get_dial_ratio.should == 2
     end

     it "dials dial_ratio times the callers available" do
       setup_callers
       setup_voters
       campaign.dials_count.should == 6
       voters = campaign.choose_voters_to_dial(campaign.dials_count)
       voters.size.should == 6
     end


     it "dials dial_ratio times the callers available for the power mode" do
       setup_callers
       setup_voters
       campaign.should_receive(:ring_predictive_voters).with([anything, anything, anything, anything, anything, anything])
       campaign.dial_predictive_voters
     end

     it "does not redial a voter that is in progress" do
       voter = Factory(:voter, :campaign => campaign, :status => CallAttempt::Status::SUCCESS)
       Factory(:call_attempt, :voter => voter, :status => CallAttempt::Status::SUCCESS)
       campaign.choose_voters_to_dial(20).should_not include(voter.id)
     end

   end

   #canned scenarios where we back into / prove our new calls / max calls

 end

 describe "ratio_dialer" do
   it "should get the dial ratio based on predictive type"
   it "should set the dial ratio to 2 if no recent calls have been answered"
 end

 describe "simulation_dialer" do

   it "should dial one line per caller if no calls have been made in the last ten minutes" do
     campaign = Factory(:campaign)
     2.times { Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true) }
     num_to_call = campaign.dial_predictive_simulator
     campaign.should_not_receive(:num_to_call_predictive_simulate)
     caller_sessions = CallerSession.find_all_by_campaign_id(campaign.id)
     num_to_call.should eq(caller_sessions.size)
   end

   it "should dial one line per caller if abandonment rate exceeds acceptable rate" do
     campaign = Factory(:campaign, :acceptable_abandon_rate => 0.2)
     Factory(:call_attempt, :campaign => campaign, :call_start => 20.seconds.ago)
     Factory(:call_attempt, :campaign => campaign, :call_start => 20.seconds.ago, :status => CallAttempt::Status::ABANDONED)
     2.times { Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true) }
     num_to_call = campaign.dial_predictive_simulator
     campaign.should_not_receive(:num_to_call_predictive_simulate)
     caller_sessions = CallerSession.find_all_by_campaign_id(campaign.id)
     num_to_call.should eq(caller_sessions.size)
   end

  it "should determine calls to make give the simulated best_dials when call_attempts prior int the last 10 mins are present" do
    simulated_values = SimulatedValues.create(best_dials: 2.33345, best_conversation: 34.0076, longest_conversation: 42.0876, best_wrapup_time: 10.076)
    campaign = Factory(:campaign, :simulated_values => simulated_values)

    10.times { Factory(:caller_session, :campaign => campaign, :on_call => true, :available_for_call => true) }
    10.times { Factory(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 10.seconds.ago, :wrapup_time => 5.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
    10.times { Factory(:call_attempt, :campaign => campaign, :call_start => 40.seconds.ago, call_end: 8.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
    3.times { Factory(:call_attempt, :campaign => campaign, :call_start => 80.seconds.ago, call_end: 38.seconds.ago, :status => CallAttempt::Status::SUCCESS) }
    Factory(:call_attempt, :campaign => campaign, :call_start => 35.seconds.ago,call_end: 10.seconds.ago, :status => CallAttempt::Status::SUCCESS)
    Factory(:call_attempt, :campaign => campaign, :call_start => 65.seconds.ago, call_end: 10.seconds.ago, :status => CallAttempt::Status::SUCCESS)
    2.times { Factory(:call_attempt, :campaign => campaign, :call_start => 10.seconds.ago, :status => CallAttempt::Status::RINGING) }
    unavailable_caller_sessions = CallerSession.all[1..7]
    unavailable_caller_sessions.each { |caller_session| caller_session.update_attribute(:available_for_call, false) }
    5.times { Factory(:call_attempt, :campaign => campaign, :call_start => 5.seconds.ago, :status => CallAttempt::Status::INPROGRESS) }
    2.times { Factory(:call_attempt, :campaign => campaign, :call_start => 20.seconds.ago, :status => CallAttempt::Status::INPROGRESS) }
    calls_to_make = campaign.num_to_call_predictive_simulate
    calls_to_make.should eq(16)
  end

  it "should determine calls to make give the simulated best_dials when call_attempts prior int the last 10 mins are present" do
      simulated_values = SimulatedValues.create(best_dials: 1, best_conversation: 0, longest_conversation: 0)
      campaign = Factory(:campaign, :simulated_values => simulated_values)
      3.times { Factory(:caller_session, :campaign => campaign, :on_call => true, :available_for_call => true) }
      calls_to_make = campaign.num_to_call_predictive_simulate
      calls_to_make.should eq(3)
    end

    it "should determine calls to make when no simulated values" do
      campaign = Factory(:campaign)
      3.times { Factory(:caller_session, :campaign => campaign, :on_call => true, :available_for_call => true) }
      calls_to_make = campaign.num_to_call_predictive_simulate
      calls_to_make.should eq(3)
    end

    describe "best dials simulated" do

      it "should return 1 as best dials if simulated_values is nil" do
        campaign = Factory(:campaign)
        campaign.best_dials_simulated.should eq(1)
      end

      it "should return 1 as best dials if  best_dials simulated_values is nil" do
        campaign = Factory(:campaign)
        campaign.best_dials_simulated.should eq(1)
      end

      it "should return best dials  if  best_dials simulated_values is has a value" do
        simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 0, longest_conversation: 0)
        campaign = Factory(:campaign, :simulated_values => simulated_values)
        campaign.best_dials_simulated.should eq(2)
      end


    end

    describe "best conversations simulated" do

      it "should return 0 as best conversation if simulated_values is nil" do
        campaign = Factory(:campaign)
        campaign.best_conversation_simulated.should eq(0)
      end

      it "should return 0 as best conversation if best_conversation simulated_values is nil" do
        campaign = Factory(:campaign)
        campaign.best_conversation_simulated.should eq(0)
      end

      it "should return best conversation if  best_conversation simulated_values is has a value" do
        simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 34.34, longest_conversation: 0)
        campaign = Factory(:campaign, :simulated_values => simulated_values)
        campaign.best_conversation_simulated.should eq(34.34)
      end


    end

    describe "longest conversations simulated" do

      it "should return 0 as longest conversation if simulated_values is nil" do
        campaign = Factory(:campaign)
        campaign.longest_conversation_simulated.should eq(0)
      end

      it "should return 0 as longest conversation if longest_conversation simulated_values is nil" do
        campaign = Factory(:campaign)
        campaign.longest_conversation_simulated.should eq(0)
      end

      it "should return longest conversation if  longest_conversation simulated_values is has a value" do
        simulated_values = SimulatedValues.create(best_dials: 1.8, best_conversation: 34.34, longest_conversation: 67.09)
        campaign = Factory(:campaign, :simulated_values => simulated_values)
        campaign.longest_conversation_simulated.should eq(67.09)
      end

    end


    it "determines if dialing is ramping up" do
      #less than 50 dials in the last 10 minutes
      campaign = Factory(:campaign)
      caller_session = Factory(:caller_session, :on_call => true, :available_for_call => true, :campaign => campaign)
      (1..10).each do |i|
        call_attempt = Factory(:call_attempt, :caller_session => caller_session, :voter => Factory(:voter), :campaign => campaign, :call_start=>Time.now, :status=>"Status: Call in progress")
      end
      campaign.should be_dials_ramping

      campaign = Factory(:campaign)
      caller_session = Factory(:caller_session, :on_call => true, :available_for_call => true, :campaign => campaign)
      (1..60).each do |i|
        call_attempt = Factory(:call_attempt, :caller_session => caller_session, :voter => Factory(:voter), :campaign => campaign, :call_start=>Time.now, :status=>"Status: Call in progress")
      end
      campaign.should_not be_dials_ramping
    end

    it "calculates callers_on_call_longer_than" do
      campaign = Factory(:campaign, :predictive_alpha=>0.8, :predictive_beta=>0.2)
      caller_session = Factory(:caller_session, :on_call => true, :available_for_call => false, :campaign => campaign)
      call_attempt = Factory(:call_attempt, :caller_session => caller_session, :voter => Factory(:voter), :campaign => campaign, :call_start=>Time.now-60, :status=>CallAttempt::Status::INPROGRESS)
      caller_session.attempt_in_progress=call_attempt

      caller_session_2 = Factory(:caller_session, :on_call => true, :available_for_call => false, :campaign => campaign)
      call_attempt_2 = Factory(:call_attempt, :caller_session => caller_session_2, :voter => Factory(:voter), :campaign => campaign, :call_start=>Time.now-30, :status=>CallAttempt::Status::INPROGRESS)
      caller_session_2.attempt_in_progress=call_attempt_2

      campaign.callers_on_call_longer_than(20).length.should==2
      campaign.callers_on_call_longer_than(50).length.should==1
      campaign.callers_on_call_longer_than(70).length.should==0
    end

    it "determines available callers" do
      campaign = Factory(:campaign, :predictive_alpha=>0.8, :predictive_beta=>0.2)
      caller_session = Factory(:caller_session, :on_call => true, :available_for_call => true, :campaign => campaign)
      (1..25).each do |i|
        short_call_attempt = Factory(:call_attempt, :caller_session => caller_session, :voter => Factory(:voter), :campaign => campaign, :call_start=>Time.now-30, :status=>"Call completed with success.", :call_end=>Time.now)
      end
      (1..25).each do |i|
        lon_call_attempt = Factory(:call_attempt, :caller_session => caller_session, :voter => Factory(:voter), :campaign => campaign, :call_start=>Time.now-600, :status=>"Call completed with success.", :call_end=>Time.now)
      end
      (1..2).each do |i|
        longer_than_expected_call_attempt = Factory(:call_attempt, :caller_session => caller_session, :voter => Factory(:voter), :campaign => campaign, :call_start=>Time.now-1400, :status=>"Call completed with success.", :call_end=>Time.now)
      end
      (1..10).each do |i|
        free_caller_session = Factory(:caller_session, :on_call => true, :available_for_call => true, :campaign => campaign)
      end
      (1..10).each do |i|
        busy_caller_session = Factory(:caller_session, :on_call => true, :available_for_call => false, :campaign => campaign)
      end

      # stats = campaign.call_stats(10)
      # puts stats[:avg_duration]
      # puts stats[:biggest_long]
      # puts campaign.dialer_available_callers
      campaign.dialer_available_callers.should==11
    end

    it "determines dials needed" do
      #  α * dials_answered / dials_made
      campaign = Factory(:campaign, :predictive_alpha=>0.8, :predictive_beta=>0.2)
      caller_session = Factory(:caller_session, :on_call => true, :available_for_call => true, :campaign => campaign)
      (1..25).each do |i|
        answered_call_attempt = Factory(:call_attempt, :caller_session => caller_session, :voter => Factory(:voter), :campaign => campaign, :call_start=>Time.now-30, :status=>"Call completed with success.", :call_end=>Time.now)
      end
      # since all dials are answered it should be equal to alpha
      campaign.dials_needed.should==campaign.predictive_alpha

      campaign_2 = Factory(:campaign, :predictive_alpha=>0.8, :predictive_beta=>0.2)
      caller_session_2 = Factory(:caller_session, :on_call => true, :available_for_call => true, :campaign => campaign_2)
      (1..25).each do |i|
        answered_call_attempt = Factory(:call_attempt, :caller_session => caller_session_2, :voter => Factory(:voter), :campaign => campaign_2, :call_start=>Time.now-30, :status=>"Call completed with success.", :call_end=>Time.now)
      end
      (1..25).each do |i|
        busy_call_attempt = Factory(:call_attempt, :caller_session => caller_session_2, :voter => Factory(:voter), :campaign => campaign_2, :call_start=>Time.now, :status=>"Busy", :call_end=>Time.now)
      end

      # since half dials are answered it should be equal to alpha/2
      campaign_2.dials_needed.should==campaign.predictive_alpha/2

    end

    it "chooses dial strategey"
    it "determines ringing lines" #need to track this by updating a flag when call is answered

  end

  describe Campaign do

    it 'return validation error, if caller id is either blank, not a number or not a valid length' do
      campaign = Campaign.new(:account => Factory(:account))
      campaign.save(:validate => false)
      campaign.update_attributes(:caller_id => '23456yuiid').should be_false
      campaign.errors[:base].should == ['Your Caller ID must be a 10-digit North American phone number or begin with "+" and the country code.']
      campaign.errors[:caller_id].should == []
    end

    it "should not have a blank caller_id" do
      campaign = Factory(:campaign, :caller_id => nil)
      campaign.should_not be_valid
    end

    it "skips validations for an international phone number" do
      campaign = Factory.build(:campaign, :caller_id => "+98743987")
      campaign.should be_valid
      campaign = Factory.build(:campaign, :caller_id => "+987AB87A")
      campaign.should be_valid
    end

    it 'return validation error, when callers are login and try to change dialing mode' do
      campaign = Campaign.create!(:name => 'Titled', :caller_id => '0123456789', :account => Factory(:account), :predictive_type =>Campaign::Type::PREVIEW)
      campaign.caller_sessions.create!(:on_call => true)
      campaign.update_attributes(:predictive_type => Campaign::Type::PROGRESSIVE).should be_false
      campaign.errors[:base].should == ['You cannot change dialing modes while callers are logged in.']
    end

    it "is_phones_only_and_preview_or_progressive? is true if is_phones_only and campaign type is preview or progressive" do
      campaign = Campaign.new(Factory.attributes_for(:campaign))
      campaign.save
      puts campaign.errors
      puts campaign.errors.full_messages
      #preview_campaign = Factory(:campaign, :predictive_type => Campaign::Type::PREVIEW)
      #preview_campaign.is_preview_or_progressive.should be_true

      #progressive_campaign = Factory(:campaign, :predictive_type => Campaign::Type::PROGRESSIVE)
      #progressive_campaign.is_preview_or_progressive.should be_true
    end

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
      campaign = user.account.campaigns.create!(:caller_id => '0123456789')
      campaign.name.should == 'Untitled 1'
      campaign = user.account.campaigns.create!(:caller_id => '0123456789')
      campaign.name.should == 'Untitled 2'
    end

    it "generates its campaign pin" do
      user = Factory(:user)
      campaign = user.account.campaigns.create!(:caller_id => '0123456789')
      campaign.campaign_id.should_not be_nil
    end

    it "doesn't overwrite a name that has been explicitly set" do
      user = Factory(:user)
      campaign = user.account.campaigns.create!(:name => 'Titled', :caller_id => '0123456789')
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

    it "returns campaigns having a session with the given caller" do
      caller = Factory(:caller)
      campaign = Factory(:campaign)
      Factory(:campaign)
      Factory(:caller_session, :campaign => campaign, :caller => caller)
      Campaign.for_caller(caller).should == [campaign]
    end

    describe "next voter to be dialed" do

      it "returns priority  not called voter first" do
        campaign = Factory(:campaign)
        voter = Factory(:voter, :status => 'not called', :campaign => campaign)
        priority_voter = Factory(:voter, :status => 'not called', :campaign => campaign, priority: "1")
        campaign.next_voter_in_dial_queue.should == priority_voter

      end
      it "returns uncalled voter before called voter" do
        campaign = Factory(:campaign)
        Factory(:voter, :status => CallAttempt::Status::SUCCESS, :last_call_attempt_time => 2.hours.ago, :campaign => campaign)
        uncalled_voter = Factory(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
        campaign.next_voter_in_dial_queue.should == uncalled_voter
      end

      it "returns any scheduled voter within a ten minute window before an uncalled voter" do
        campaign = Factory(:campaign)
        scheduled_voter = Factory(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 1.minute.from_now, :campaign => campaign)
        Factory(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
        campaign.next_voter_in_dial_queue.should == scheduled_voter
      end

      it "returns next voter in list if scheduled voter is more than 10 minutes away from call" do
        campaign = Factory(:campaign)
        scheduled_voter = Factory(:voter, :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 20.minute.from_now, :campaign => campaign)
        current_voter = Factory(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
        next_voter = Factory(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
        campaign.next_voter_in_dial_queue(current_voter.id).should == next_voter
      end


      it "returns voter with respect to a current voter" do
        campaign = Factory(:campaign)
        uncalled_voter = Factory(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
        current_voter = Factory(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
        next_voter = Factory(:voter, :status => Voter::Status::NOTCALLED, :campaign => campaign)
        campaign.next_voter_in_dial_queue(current_voter.id).should == next_voter
      end

      it "returns no number if only voter to be called a retry and last called time is within campaign recycle rate" do
        time_now = Time.now.utc
        Time.stub(:now).and_return(time_now)
        campaign = Factory(:campaign, recycle_rate: 2)
        scheduled_voter = Factory(:voter, :FirstName => 'scheduled voter', :status => CallAttempt::Status::SCHEDULED, :last_call_attempt_time => 2.hours.ago, :scheduled_date => 20.minutes.from_now, :campaign => campaign)
        retry_voter = Factory(:voter, :status => CallAttempt::Status::VOICEMAIL, last_call_attempt_time: 1.hours.ago, :campaign => campaign)
        current_voter = Factory(:voter, :status => CallAttempt::Status::SUCCESS, :campaign => campaign)
        campaign.next_voter_in_dial_queue(current_voter.id).should be_nil
      end
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

      it "should return caller session, which is oldest and available to take call" do
        campaign = Factory(:campaign)
        caller_session1 = Factory(:caller_session, :campaign => campaign, :on_call => true)
        caller_session2 = Factory(:caller_session, :campaign => campaign, :on_call => true)
        caller_session3 = Factory(:caller_session, :campaign => campaign, :on_call => true)
        caller_session2.update_attributes(:available_for_call => true)
        caller_session1.update_attributes(:available_for_call => true, :updated_at => Time.now + 1.second)
        caller_session3.update_attributes(:updated_at => Time.now + 5.second)
        campaign.oldest_available_caller_session.should == caller_session2

      end
    end

    describe "voicemails" do
      it "are left when a voicemail script is present" do
        campaign = Factory(:campaign, :robo => true, :voicemail_script => Factory(:script, :robo => true, :for_voicemail => true))
        campaign.leave_voicemail?.should be_true
      end

      it "are not left when a voicemail script is absent" do
        campaign = Factory(:campaign, :robo => true)
        campaign.leave_voicemail?.should be_false
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
        lists = 2.times.map { Factory(:voter_list, :campaign => campaign).tap { |list| list.should_receive(:dial) } }
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
        Campaign.send(:define_method, :dial_voters) do
          self.calls_in_progress?.should == true
        end
        campaign = Factory(:campaign)
        campaign.dial
        campaign.calls_in_progress.should == false
      end

      it "does not start the dialer daemon for the campaign if the use has not already paid" do
        campaign = Factory(:campaign, :account => Factory(:account, :activated => false))
        campaign.start(Factory(:user)).should be_false
      end

      it "does not start the dialer daemon for the campaign if it is already started" do
        campaign = Factory(:campaign, :calls_in_progress => true)
        campaign.start(Factory(:user)).should be_false
      end

      it "starts the dialer daemon for the campaign if there are recordings to play" do
        script = Factory(:script)
        script.robo_recordings = [Factory(:robo_recording)]
        campaign = Factory(:campaign, :script => script, :account => Factory(:account, :activated => true))
        Delayed::Job.should_receive(:enqueue)
        campaign.start(Factory(:user)).should be_true
        campaign.calls_in_progress.should be_true
      end

      it "does not start the dialer daemon for the campaign if its script has nothing to play" do
        script = Factory(:script)
        script.robo_recordings.size.should == 0
        campaign = Factory(:campaign, :script => script, :account => Factory(:account, :activated => true))
        campaign.start(Factory(:user)).should be_false
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
      voters = 3.times.map { Factory(:voter, :campaign => campaign, :result => 'foo', :status => 'bar') }
      voter_on_another_campaign = Factory(:voter, :result => 'hello', :status => 'world')
      campaign.clear_calls
      voters.each(&:reload).each do |voter|
        voter.result.should be_nil
        voter.status.should == 'not called'
      end
      voter_on_another_campaign.result.should == 'hello'
      voter_on_another_campaign.status.should == 'world'
    end

    describe "answer report" do
        let(:script) { Factory(:script)}
        let(:campaign) { Factory(:campaign, :script => script) }
        let(:call_attempt1) { Factory(:call_attempt,:campaign => campaign) }
        let(:call_attempt2) { Factory(:call_attempt,:campaign => campaign) }
        let(:call_attempt3) { Factory(:call_attempt,:campaign => campaign) }
        let(:call_attempt4) { Factory(:call_attempt,:campaign => campaign) }

        let(:voter1) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt1)}
        let(:voter2) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt2)}
        let(:voter3) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt3)}
        let(:voter4) { Factory(:voter, :campaign => campaign, :last_call_attempt => call_attempt4)}

      it "should give the final results of a campaign as a Hash" do
        now = Time.now
        campaign2 = Factory(:campaign)
        question1 = Factory(:question, :text => "hw are u", :script => script)
        question2 = Factory(:question, :text => "wr r u", :script => script)
        possible_response1 = Factory(:possible_response, :value => "fine", :question => question1)
        possible_response2 = Factory(:possible_response, :value => "super", :question => question1)
        possible_response3 = Factory(:possible_response, :value => "[No response]", :question => question1)
        Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response1, :question => question1, :created_at => now)
        Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question1, :created_at => now)
        Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response3, :question => question1, :created_at => now)
        Factory(:answer, :voter => Factory(:voter, :campaign => campaign2), campaign: campaign2, :possible_response => possible_response2, :question => question2, :created_at => now)
        campaign.answers_result(now, now).should == {"hw are u" => [{answer: possible_response1.value, number: 1, percentage: 33}, {answer: possible_response2.value, number: 1, percentage: 33}, {answer: possible_response3.value, number: 1, percentage: 33}], "wr r u" => [{answer: "[No response]", number: 0, percentage: 0}]}
      end

      it "should give the final results of a campaign as a Hash" do
        now = Time.now
        campaign2 = Factory(:campaign)
        robo_recording1 = Factory(:robo_recording, :name => "hw are u", :script => script)
        robo_recording2 = Factory(:robo_recording, :name => "wr r u", :script => script)
        recording_response1 = Factory(:recording_response, :response => "fine", :robo_recording => robo_recording1,:keypad => 1)
        recording_response2 = Factory(:recording_response, :response => "super", :robo_recording => robo_recording1,:keypad => 2)
        recording_response3 = Factory(:recording_response, :response => "[No response]", :robo_recording => robo_recording1,:keypad => 3)

        call_attempt1.update_attributes(:voter => voter1)
        call_attempt2.update_attributes(:voter => voter2)
        call_attempt3.update_attributes(:voter => voter3)
        call_attempt4.update_attributes(:voter => voter4)

        Factory(:call_response, :call_attempt => call_attempt1, campaign: campaign, :recording_response => recording_response1, :robo_recording => robo_recording1, :created_at => now)
        Factory(:call_response, :call_attempt => call_attempt2, campaign: campaign,:recording_response => recording_response2, :robo_recording => robo_recording1, :created_at => now)
        Factory(:call_response, :call_attempt => call_attempt3, campaign: campaign,:recording_response => recording_response3, :robo_recording => robo_recording1, :created_at => now)
        Factory(:call_response, :call_attempt => call_attempt4, campaign: campaign2, :recording_response => recording_response2, :robo_recording => robo_recording2, :created_at => now)
        campaign.robo_answer_results(now, now).should == {"hw are u" => [{answer: recording_response1.response, number: 1, percentage: 33}, {answer: recording_response2.response, number: 1, percentage: 33}, {answer: recording_response3.response, number: 1, percentage: 33}], "wr r u" => [{answer: "[No response]", number: 0, percentage: 0}]}
      end
    end

    describe "time period" do
      before(:each) do
        @campaign = Factory(:campaign, :start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
      end

      it "should allow callers to dial, if time not expired" do
        t1 = Time.parse("01/2/2011 10:00")
        t2 = Time.parse("01/2/2011 09:00")
        Time.stub!(:now).and_return(t1, t1, t2, t2)
        @campaign.time_period_exceed?.should == false
      end

      it "should not allow callers to dial, if time  expired" do
        t1 = Time.parse("01/2/2011 22:20")
        t2 = Time.parse("01/2/2011 11:00")
        t3 = Time.parse("01/2/2011 15:00")
        Time.stub!(:now).and_return(t1, t1, t2, t2, t3, t3)
        @campaign.time_period_exceed?.should == true
      end
    end

end
