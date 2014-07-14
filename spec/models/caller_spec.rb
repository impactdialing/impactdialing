require "spec_helper"

describe Caller do
  include Rails.application.routes.url_helpers

  it {should belong_to :caller_group}

  it 'assigns itself to the campaign of its caller group' do
    campaign = create(:preview)
    caller_group = create(:caller_group, campaign_id: campaign.id)
    caller = create(:caller, caller_group_id: caller_group.id)
    caller.campaign.should eq campaign
  end

  it 'saves successfully if it does not have a caller group' do
    caller_group = create(:caller_group)
    caller = create(:caller, caller_group_id: caller_group.id)
    campaign = create(:preview)
    caller.update_attributes(caller_group_id: nil, campaign: campaign)
    caller.save.should be_truthy
  end

  it "should validate name for phones only callers" do
    caller_group = create(:caller_group)
    caller = build(:caller, caller_group_id: caller_group.id, is_phones_only: true, name: "")
    caller.save.should be_falsey
    caller.errors.messages.should eq({:name=>["can't be blank"]})
  end

  it "should validate username for web callers" do
    caller_group = create(:caller_group)
    caller = build(:caller, caller_group_id: caller_group.id, is_phones_only: false, name: "", username: "")
    caller.save.should be_falsey
    caller.errors.messages.should eq({:username=>["can't be blank"]})
  end

  it "should validate username cant contain spces for web callers" do
    caller_group = create(:caller_group)
    caller = build(:caller, caller_group_id: caller_group.id, is_phones_only: false, name: "", username: "john doe")
    caller.save.should be_falsey
    caller.errors.messages.should eq({:username=>["cannot contain blank space."]})
  end


  let(:user) { create(:user) }
  it "restoring makes it active" do
    caller_object = create(:caller, :active => false)
    caller_object.restore
    caller_object.active?.should == true
  end

  it "sorts by the updated date" do
    Caller.record_timestamps = false
    older_caller = create(:caller).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
    newer_caller = create(:caller).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
    Caller.record_timestamps = true
    Caller.by_updated.all.should include(newer_caller, older_caller)
  end

  it "lists active callers" do
    active_caller = create(:caller, :active => true)
    inactive_caller = create(:caller, :active => false)
    Caller.active.should include(active_caller)
  end

  it "validates that a restored caller has an active campaign" do
    campaign = create(:campaign, active: false)
    caller = create(:caller, campaign: campaign, active: false)
    caller.active = true
    caller.save.should be_falsey
    caller.errors[:base].should == ['The campaign this caller was assigned to has been deleted. Please assign the caller to a new campaign.']
  end

  it "asks for pin" do
    Caller.ask_for_pin(0, nil).should ==
        Twilio::Verb.new do |v|
          3.times do
            v.gather(:finishOnKey => '*', :timeout => 10, :action => identify_caller_url(:host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => 'http://', :attempt => 1), :method => "POST") do
              v.say "Please enter your pin and then press star."
            end
          end
        end.response
  end

  it "asks for pin again" do
    Caller.ask_for_pin(1,nil).should == Twilio::Verb.new do |v|
      3.times do
        v.gather(:finishOnKey => '*', :timeout => 10, :action => identify_caller_url(:host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => 'http://', :attempt => 2), :method => "POST") do
          v.say "Incorrect Pin. Please enter your pin and then press star."
        end
      end
    end.response
  end

  it "returns name for phone-only-caller, email for web-caller " do
    phones_only_caller = create(:caller, :is_phones_only => true, :name => "name", :username => "email1@gmail.com")
    web_caller = create(:caller, :is_phones_only => false, :name => "name", :username => "email2@gmail.com")
    phones_only_caller.identity_name.should == "name"
    web_caller.identity_name.should == "email2@gmail.com"
  end


  describe "reports" do
    let(:caller) { create(:caller, :account => user.account) }
    let!(:from_time) { 5.minutes.ago }
    let!(:time_now) { Time.now }

    before(:each) do
      create(:caller_session, caller_type: "Phone", tStartTime: Time.now, tEndTime: Time.now + (30.minutes + 2.seconds), :tDuration => 30.minutes + 2.seconds, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:caller_session, tStartTime: Time.now, tEndTime: Time.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (10.minutes + 10.seconds), wrapup_time: Time.now + (10.minutes + 40.seconds), :tDuration => 10.minutes + 10.seconds, :status => CallAttempt::Status::SUCCESS, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (101.minutes + 57.seconds), wrapup_time: Time.now + (102.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      create(:call_attempt, connecttime: Time.now, tStartTime: Time.now, tEndTime: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
    end

    describe "utilization" do
      it "lists time logged in" do
        CallerSession.time_logged_in(caller, nil, from_time, time_now).should == 7919
      end

      it "lists on call time" do
        CallAttempt.time_on_call(caller, nil, from_time, time_now).should == 6727
      end

      it "lists on wrapup time" do
        CallAttempt.time_in_wrapup(caller, nil, from_time, time_now).should == 90
      end


    end

    describe "billing" do
      it "lists caller time" do
        CallerSession.caller_time(caller, nil, from_time, time_now).should == 31
      end

      it "lists lead time" do
        CallAttempt.lead_time(caller, nil, from_time, time_now).should == 113
      end
    end

    describe "campaign" do


      it "gets stats for answered calls" do
        @voter =  create(:voter)
        @script = create(:script)
        @question = create(:question, :text => "what?", script: @script)
        response_1 = create(:possible_response, :value => "foo", question: @question)
        response_2 = create(:possible_response, :value => "bar", question: @question)
        campaign = create(:campaign, script: @script)
        3.times { create(:answer, :caller => caller, :voter => @voter, :question_id => @question.id, :possible_response => response_1, :campaign => campaign) }
        2.times { create(:answer, :caller => caller, :voter => @voter, :question_id => @question.id, :possible_response => response_2, :campaign => campaign) }
        create(:answer, :caller => caller, :voter => @voter, :question => @question, :possible_response => response_1, :campaign => create(:campaign))
        stats = caller.answered_call_stats(from_time, time_now+1.day, campaign)
        stats.should == {"what?"=>[{:answer=>"[No response]", :number=>0, :percentage=>0},{:answer=>"foo", :number=>3, :percentage=>60}, {:answer=>"bar", :number=>2, :percentage=>40}]}
      end
    end
  end

  describe "reassign caller campaign" do
    it "should do nothing if campaign not changed" do
      campaign = create(:campaign)
      caller = create(:caller, campaign: campaign)
      caller.should_not_receive(:is_phones_only?)
      caller.save
    end

    it "should do nothing if campaign changed but caller not logged in" do
      campaign = create(:campaign)
      other_campaign = create(:campaign)
      caller_session = create(:caller_session, on_call: false)
      caller = create(:caller, campaign: campaign)
      caller.update_attributes(campaign_id: other_campaign.id)
      caller_session.reassign_campaign.should eq(CallerSession::ReassignCampaign::NO)
    end

    it "should set on call caller session to reassigned yes" do
      campaign = create(:campaign)
      other_campaign = create(:campaign)
      caller = create(:caller, campaign: campaign, is_phones_only: true)
      caller_session = create(:caller_session, on_call: true, campaign: campaign, caller_id: caller.id)
      caller.update_attributes!(campaign: other_campaign)
      caller_session.reload.reassign_campaign.should eq(CallerSession::ReassignCampaign::YES)
    end

    it "should set on ReassignedCallerSession campaign id" do
      campaign = create(:campaign)
      other_campaign = create(:campaign)
      caller = create(:caller, campaign: campaign, is_phones_only: true)
      caller_session = create(:caller_session, on_call: true, campaign: campaign, caller_id: caller.id)
      caller.update_attributes!(campaign: other_campaign)
      RedisReassignedCallerSession.campaign_id(caller_session.id).should eq(other_campaign.id.to_s)
    end


  end

  describe "started calling" do

    it "should  push campaign and caller to redis " do
      campaign = create(:predictive)
      caller  = create(:caller, campaign: campaign)
      caller_session = create(:caller_session, caller: caller)
      RedisPredictiveCampaign.should_receive(:add).with(campaign.id, campaign.type)
      RedisStatus.should_receive(:set_state_changed_time).with(campaign.id, "On hold", caller_session.id)
      caller.started_calling(caller_session)
    end

  end

  describe "calling_voter_preview_power" do
    it "should call pusher and enqueue dial " do
      campaign = create(:predictive)
      caller  = create(:caller, campaign: campaign)
      caller_session = create(:caller_session, caller: caller)
      voter = create(:voter)
      caller.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_calling_voter"])
      caller.should_receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, voter.id])
      caller.calling_voter_preview_power(caller_session, voter.id)
    end

  end
end
