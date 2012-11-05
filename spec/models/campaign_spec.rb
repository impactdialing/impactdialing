require "spec_helper"


describe Campaign do

  describe "voter" do

   it "should return zero voters, if active_voter_list_ids is empty" do
     campaign = Factory(:campaign, :account => Factory(:account, :activated => true), type: Campaign::Type::PREVIEW)
     VoterList.should_receive(:active_voter_list_ids).with(campaign.id).and_return([])
     campaign.voters("not called").should == []
   end

   it "should return voters to be call" do
     campaign = Factory(:campaign, :account => Factory(:account, :activated => true), recycle_rate: 3,type: Campaign::Type::PREVIEW)
     VoterList.should_receive(:active_voter_list_ids).with(campaign.id).and_return([12, 123])
     Voter.should_receive(:to_be_called).with(campaign.id, [12, 123], "not called", 3).and_return(["v1", "v2", "v3", "v2"])
     Voter.should_not_receive(:just_called_voters_call_back).with(campaign.id, [12, 123])
     campaign.voters("not called").length.should == 3
   end

  end

  describe "validations" do
    it {should validate_presence_of :name}
    it {should validate_presence_of :script}
    it {should validate_presence_of :type}
    it {should ensure_inclusion_of(:type).in_array(['Preview', 'Progressive', 'Predictive'])}
    it {should validate_presence_of :recycle_rate}
    it {should validate_numericality_of :recycle_rate}
    it {should validate_presence_of :time_zone}
    it {should ensure_inclusion_of(:time_zone).in_array(ActiveSupport::TimeZone.zones_map.map {|z| z.first})}
    it {should validate_presence_of :start_time}
    it {should validate_presence_of :end_time}
    it {should validate_numericality_of :acceptable_abandon_rate}
    it {should have_many :caller_groups}

    it 'return validation error, if caller id is either blank, not a number or not a valid length' do
      campaign = Campaign.new(:account => Factory(:account))
      campaign.save(:validate => false)
      campaign.update_attributes(:caller_id => '23456yuiid').should be_false
      campaign.errors[:base].should == ['Caller ID must be a 10-digit North American phone number or begin with "+" and the country code']
      campaign.update_attributes(:called_id => '').should be_false
      campaign.errors[:base].should == ['Caller ID must be a 10-digit North American phone number or begin with "+" and the country code']
    end

    it "skips validations for an international phone number" do
      campaign = Factory.build(:campaign, :caller_id => "+98743987")
      campaign.should be_valid
      campaign = Factory.build(:campaign, :caller_id => "+987AB87A")
      campaign.should be_valid
    end

    it 'return validation error, when callers are login and try to change dialing mode' do
      campaign = Factory(:preview)
      campaign.caller_sessions.create!(on_call: true, state: "initial")
      campaign.type = Campaign::Type::PROGRESSIVE
      campaign.save.should be_false
      campaign.errors[:base].should == ['You cannot change dialing modes while callers are logged in.']
      campaign.reload
      campaign.type.should eq(Campaign::Type::PREVIEW)
    end

    it 'can change dialing mode when not on call' do
      campaign = Factory(:preview)
      campaign.type = Campaign::Type::PROGRESSIVE
      campaign.save.should be_true
      campaign.type.should eq(Campaign::Type::PROGRESSIVE)
    end


    it "should not invoke Twilio if caller id is not present" do
      TwilioLib.should_not_receive(:new)
      campaign = Factory(:campaign, :type =>Campaign::Type::PREVIEW)
      campaign.caller_id = nil
      campaign.save
    end

    describe "delete campaign" do

      it "should not delete a campaign that has active callers assigned to it" do
        caller = Factory(:caller)
        campaign = Factory(:preview, callers: [caller])
        campaign.active = false
        campaign.save.should be_false
        campaign.errors[:base].should == ['There are currently callers assigned to this campaign. Please assign them to another campaign before deleting this one.']
      end

      it "should  delete a campaign that has no active callers assigned to it" do
        caller = Factory(:caller)
        campaign = Factory(:preview)
        campaign.active = false
        campaign.save.should be_true
      end

      it "should delete a campaign that has inactive callers assigned to it and change their campaign to nil" do
        campaign = Factory(:campaign)
        caller = Factory(:caller, campaign: campaign, active: false)
        campaign.active = false
        campaign.save.should be_true
      end
    end

  end


  describe "campaigns with caller sessions that are on call" do
    let(:user) { Factory(:user) }
    let(:campaign) { Factory(:preview, :account => user.account) }

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

  describe "answer report" do
      let(:script) { Factory(:script)}
      let(:campaign) { Factory(:predictive, :script => script) }
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
      campaign2 = Factory(:predictive)
      question1 = Factory(:question, :text => "hw are u", :script => script)
      question2 = Factory(:question, :text => "wr r u", :script => script)
      possible_response1 = Factory(:possible_response, :value => "fine", :question => question1)
      possible_response2 = Factory(:possible_response, :value => "super", :question => question1)
      possible_response3 = Factory(:possible_response, :value => "[No response]", :question => question1)
      Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response1, :question => question1, :created_at => now)
      Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question1, :created_at => now)
      Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response3, :question => question1, :created_at => now)
      Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response2, :question => question2, :created_at => now)
      campaign.answers_result(now, now).should == {script.id => {script: script.name, questions: {"hw are u" => [{answer: possible_response1.value, number: 1, percentage: 33}, {answer: possible_response2.value, number: 2, percentage: 66}, {answer: possible_response3.value, number: 1, percentage: 33}], "wr r u" => [{answer: "[No response]", number: 0, percentage: 0}]}}}
    end

    it "should give the final results of a campaign as a Hash" do
      now = Time.now
      new_script = Factory(:script, name: 'new script')
      campaign2 = Factory(:predictive)
      question1 = Factory(:question, :text => "hw are u", :script => script)
      question2 = Factory(:question, :text => "whos your daddy", :script => new_script)
      possible_response1 = Factory(:possible_response, :value => "fine", :question => question1)
      possible_response2 = Factory(:possible_response, :value => "super", :question => question1)
      possible_response3 = Factory(:possible_response, :value => "john", :question => question2)
      possible_response4 = Factory(:possible_response, :value => "dou", :question => question2)
      Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response1, :question => question1, :created_at => now)
      Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response2, :question => question1, :created_at => now)
      Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign,:possible_response => possible_response3, :question => question2, :created_at => now)
      Factory(:answer, :voter => Factory(:voter, :campaign => campaign), campaign: campaign, :possible_response => possible_response4, :question => question2, :created_at => now)
      campaign.answers_result(now, now).should == {
        script.id => {
          script: script.name,
          questions: {
            "hw are u" => [
              {answer: possible_response1.value, number: 1, percentage: 50},
              {answer: possible_response2.value, number: 1, percentage: 50},
              {:answer=>"[No response]", :number=>0, :percentage=>0}
            ]
          }
        },
        new_script.id => {
          script: new_script.name,
          questions: {
            "whos your daddy" => [
              {answer: possible_response3.value, number: 1, percentage: 50},
              {answer: possible_response4.value, number: 1, percentage: 50},
              {:answer=>"[No response]", :number=>0, :percentage=>0}
            ]
          }
        }
      }
    end

  end

  describe "time period" do
    before(:each) do
      @campaign = Factory(:preview, :start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
    end

    it "should allow callers to dial, if time not expired" do
      t1 = Time.parse("01/2/2011 10:00 -08:00")
      t2 = Time.parse("01/2/2011 09:00 -08:00")
      Time.stub!(:now).and_return(t1, t1, t2, t2)
      @campaign.time_period_exceeded?.should == false
    end

    it "should not allow callers to dial, if time  expired" do
      t1 = Time.parse("01/2/2011 22:20 -08:00")
      t2 = Time.parse("01/2/2011 11:00 -08:00")
      t3 = Time.parse("01/2/2011 15:00 -08:00")
      Time.stub!(:now).and_return(t1, t1, t2, t2, t3, t3)
      @campaign.time_period_exceeded?.should == true
    end
  end

   it "restoring makes it active" do
     campaign = Factory(:campaign, :active => false)
     campaign.restore
     campaign.should be_active
   end

   describe "scopes" do

     it "gives only active voter lists" do
       campaign = Factory(:preview)
       active_voterlist = Factory(:voter_list, :campaign => campaign, :active => true)
       inactive_voterlist = Factory(:voter_list, :campaign => campaign, :active => false)
       campaign.voter_lists.should == [active_voterlist]
     end

     it "returns campaigns having a session with the given caller" do
       caller = Factory(:caller)
       campaign = Factory(:preview)
       Factory(:caller_session, :campaign => campaign, :caller => caller)
       Campaign.for_caller(caller).should == [campaign]
     end

     it "sorts by the updated date" do
       Campaign.record_timestamps = false
       older_campaign = Factory(:progressive).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
       newer_campaign = Factory(:progressive).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
       Campaign.record_timestamps = true
       Campaign.by_updated.all.should include (newer_campaign)
       Campaign.by_updated.all.should include (older_campaign)
       
     end

     it "lists deleted campaigns" do
       deleted_campaign = Factory(:progressive, :active => false)
       other_campaign = Factory(:progressive, :active => true)
       Campaign.deleted.should == [deleted_campaign]
     end

     it "should return active campaigns" do
       campaign1 = Factory(:progressive)
       campaign2 = Factory(:preview)
       campaign3 = Factory(:predictive, :active => false)
       Campaign.active.should include(campaign1)
       Campaign.active.should include(campaign2) 
     end
  end

  describe "cost_per_minute" do

    it "should be .09" do
      campaign = Factory(:preview)
      campaign.cost_per_minute.should eq(0.09)
    end

  end
  
  describe "callers_status" do
    
    before (:each) do
      @campaign = Factory(:preview)
      @caller_session1 = Factory(:webui_caller_session, campaign_id: @campaign.id, on_call:true, available_for_call: true)
      @caller_session2 = Factory(:webui_caller_session, on_call:true, available_for_call: false, campaign_id: @campaign.id)            
    end
    
    it "should return callers logged in" do
      puts @campaign.callers_status
      @campaign.callers_status[0].should eq(2)
    end
    
    it "should return callers on hold" do
      @campaign.callers_status[1].should eq(1)
    end
    
    it "should return callers on call" do
      @campaign.callers_status[2].should eq(1)
    end
    
    
  end
  
  describe "call_status" do
    
    it "should return attempts in wrapup" do
      campaign = Factory(:preview)
      caller_attempt1 = Factory(:call_attempt, wrapup_time: nil, created_at: 3.minutes.ago, status:  CallAttempt::Status::SUCCESS, campaign_id: campaign.id)
      caller_attempt2 = Factory(:call_attempt, wrapup_time: nil, created_at: 7.minutes.ago, status:  CallAttempt::Status::SUCCESS, campaign_id: campaign.id)      
      campaign.call_status[0].should eq(1)
    end
    
    it "should return live calls" do
      campaign = Factory(:preview)
      caller_attempt1 = Factory(:call_attempt, wrapup_time: nil, created_at: 3.minutes.ago, status:  CallAttempt::Status::INPROGRESS, campaign_id: campaign.id)
      caller_attempt2 = Factory(:call_attempt, wrapup_time: nil, created_at: 7.minutes.ago, status:  CallAttempt::Status::INPROGRESS, campaign_id: campaign.id)      
      campaign.call_status[2].should eq(1)
    end
    
    it "should return ringing_lines" do
      campaign = Factory(:preview)
      caller_attempt1 = Factory(:call_attempt, wrapup_time: nil, created_at: 12.seconds.ago, status:  CallAttempt::Status::RINGING, campaign_id: campaign.id)
      caller_attempt2 = Factory(:call_attempt, wrapup_time: nil, created_at: 7.minutes.ago, status:  CallAttempt::Status::RINGING, campaign_id: campaign.id)      
      campaign.call_status[1].should eq(1)
    end
    
    
    
  end
  
  describe "current status" do
    it "should return campaign details" do
      campaign = Factory(:predictive)
      c1= Factory(:phones_only_caller_session, on_call: false, available_for_call: false, campaign: campaign)
      
      c2= Factory(:webui_caller_session, on_call: true, available_for_call: false, attempt_in_progress: Factory(:call_attempt, connecttime: Time.now), campaign: campaign, state: "paused")
      c3= Factory(:phones_only_caller_session, on_call: true, available_for_call: false, attempt_in_progress: Factory(:call_attempt, connecttime: Time.now), campaign: campaign, state: "voter_response")
      c4= Factory(:phones_only_caller_session, on_call: true, available_for_call: false, attempt_in_progress: Factory(:call_attempt, connecttime: Time.now), campaign: campaign, state: "wrapup_call")
      
      c5= Factory(:webui_caller_session, on_call: true, available_for_call: true, attempt_in_progress: Factory(:call_attempt, campaign: campaign, status: CallAttempt::Status::RINGING, created_at: Time.now), campaign: campaign)      
      c6= Factory(:phones_only_caller_session, on_call: true, available_for_call: true, campaign: campaign)
      c7= Factory(:webui_caller_session, on_call: true, available_for_call: true, attempt_in_progress: Factory(:call_attempt, campaign: campaign, status: CallAttempt::Status::RINGING, created_at: Time.now), campaign: campaign)
      c8= Factory(:webui_caller_session, on_call: true, available_for_call: false, attempt_in_progress: Factory(:call_attempt), campaign: campaign, attempt_in_progress: Factory(:call_attempt, connecttime: Time.now), state: "connected")
      c9= Factory(:phones_only_caller_session, on_call: true, available_for_call: false, campaign: campaign, attempt_in_progress: Factory(:call_attempt, connecttime: Time.now), state: "conference_started_phones_only_predictive")
      
      c10= Factory(:webui_caller_session, on_call: true, available_for_call: true, attempt_in_progress: Factory(:call_attempt, connecttime: Time.now), campaign: campaign)
      RedisStatus.set_state_changed_time(campaign.id, "On hold", c2.id)
      RedisStatus.set_state_changed_time(campaign.id, "On hold", c5.id)
      RedisStatus.set_state_changed_time(campaign.id, "On hold", c6.id)
      RedisStatus.set_state_changed_time(campaign.id, "On hold", c7.id)
      
      RedisStatus.set_state_changed_time(campaign.id, "On call", c8.id)
      RedisStatus.set_state_changed_time(campaign.id, "On call", c9.id)
      
      RedisStatus.set_state_changed_time(campaign.id, "Wrap up", c3.id)
      RedisStatus.set_state_changed_time(campaign.id, "Wrap up", c4.id)
      RedisStatus.set_state_changed_time(campaign.id, "Wrap up", c10.id)
      
      campaign.current_status.should eq ({callers_logged_in: 9, on_call: 2, wrap_up: 3, on_hold: 4, ringing_lines: 2, available: 0})
      
    end
  end
     
end


