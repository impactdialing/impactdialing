require "spec_helper"

describe Caller, :type => :model do
  include Rails.application.routes.url_helpers

  it {is_expected.to belong_to :caller_group}

  it 'assigns itself to the campaign of its caller group' do
    campaign = create(:preview)
    caller_group = create(:caller_group, campaign_id: campaign.id)
    caller = create(:caller, caller_group_id: caller_group.id)
    expect(caller.campaign).to eq campaign
  end

  it 'saves successfully if it does not have a caller group' do
    caller_group = create(:caller_group)
    caller = create(:caller, caller_group_id: caller_group.id)
    campaign = create(:preview)
    caller.update_attributes(caller_group_id: nil, campaign: campaign)
    expect(caller.save).to be_truthy
  end

  it "should validate name for phones only callers" do
    caller_group = create(:caller_group)
    caller = build(:caller, caller_group_id: caller_group.id, is_phones_only: true, name: "")
    expect(caller.save).to be_falsey
    expect(caller.errors.messages).to eq({:name=>["can't be blank"]})
  end

  it "should validate username for web callers" do
    caller_group = create(:caller_group)
    caller = build(:caller, caller_group_id: caller_group.id, is_phones_only: false, name: "", username: "")
    expect(caller.save).to be_falsey
    expect(caller.errors.messages).to eq({:username=>["can't be blank"]})
  end

  it "should validate username cant contain spces for web callers" do
    caller_group = create(:caller_group)
    caller = build(:caller, caller_group_id: caller_group.id, is_phones_only: false, name: "", username: "john doe")
    expect(caller.save).to be_falsey
    expect(caller.errors.messages).to eq({:username=>["cannot contain blank space."]})
  end


  let(:user) { create(:user) }
  it "restoring makes it active" do
    caller_object = create(:caller, :active => false)
    caller_object.restore
    expect(caller_object.active?).to eq(true)
  end

  it "sorts by the updated date" do
    Caller.record_timestamps = false
    older_caller = create(:caller).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
    newer_caller = create(:caller).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
    Caller.record_timestamps = true
    expect(Caller.by_updated.all).to include(newer_caller, older_caller)
  end

  it "lists active callers" do
    active_caller = create(:caller, :active => true)
    inactive_caller = create(:caller, :active => false)
    expect(Caller.active).to include(active_caller)
  end

  it "validates that a restored caller has an active campaign" do
    campaign = create(:campaign, active: false)
    caller = create(:caller, campaign: campaign, active: false)
    caller.active = true
    expect(caller.save).to be_falsey
    expect(caller.errors[:base]).to eq(['The campaign this caller was assigned to has been deleted. Please assign the caller to a new campaign.'])
  end

  it "asks for pin" do
    expect(Caller.ask_for_pin(0, nil)).to eq(
        Twilio::Verb.new do |v|
          3.times do
            v.gather(:finishOnKey => '*', :timeout => 10, :action => identify_caller_url(:host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => 'http://', :attempt => 1), :method => "POST") do
              v.say "Please enter your pin and then press star."
            end
          end
        end.response
    )
  end

  it "asks for pin again" do
    expect(Caller.ask_for_pin(1,nil)).to eq(Twilio::Verb.new do |v|
      3.times do
        v.gather(:finishOnKey => '*', :timeout => 10, :action => identify_caller_url(:host => Settings.twilio_callback_host, :port => Settings.twilio_callback_port, :protocol => 'http://', :attempt => 2), :method => "POST") do
          v.say "Incorrect Pin. Please enter your pin and then press star."
        end
      end
    end.response)
  end

  it "returns name for phone-only-caller, email for web-caller " do
    phones_only_caller = create(:caller, :is_phones_only => true, :name => "name", :username => "email1@gmail.com")
    web_caller = create(:caller, :is_phones_only => false, :name => "name", :username => "email2@gmail.com")
    expect(phones_only_caller.identity_name).to eq("name")
    expect(web_caller.identity_name).to eq("email2@gmail.com")
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
        expect(CallerSession.time_logged_in(caller, nil, from_time, time_now)).to eq(7919)
      end

      it "lists on call time" do
        expect(CallAttempt.time_on_call(caller, nil, from_time, time_now)).to eq(6727)
      end

      it "lists on wrapup time" do
        expect(CallAttempt.time_in_wrapup(caller, nil, from_time, time_now)).to eq(90)
      end


    end

    describe "billing" do
      it "lists caller time" do
        expect(CallerSession.caller_time(caller, nil, from_time, time_now)).to eq(31)
      end

      it "lists lead time" do
        expect(CallAttempt.lead_time(caller, nil, from_time, time_now)).to eq(113)
      end
    end

    describe "campaign" do
      it "gets stats for answered calls" do
        @voter =  create(:voter)
        @script = create(:script)
        @question = create(:question, :text => "what?", script: @script)
        response_1 = create(:possible_response, :value => "foo", question: @question, possible_response_order: 1)
        response_2 = create(:possible_response, :value => "bar", question: @question, possible_response_order: 2)
        campaign = create(:campaign, script: @script)
        3.times { create(:answer, :caller => caller, :voter => @voter, :question_id => @question.id, :possible_response => response_1, :campaign => campaign) }
        2.times { create(:answer, :caller => caller, :voter => @voter, :question_id => @question.id, :possible_response => response_2, :campaign => campaign) }
        create(:answer, :caller => caller, :voter => @voter, :question => @question, :possible_response => response_1, :campaign => create(:campaign))
        stats = caller.answered_call_stats(from_time, time_now+1.day, campaign)

        expect(stats).to eq({
          "what?" => [
            {
              :answer=>"[No response]",
              :number=>0,
              :percentage=>0
            },
            {
              :answer=>"foo",
              :number=>3,
              :percentage=>60
            },
            {
              :answer=>"bar",
              :number=>2,
              :percentage=>40
            }
          ]
        })
      end
    end
  end

  describe "reassign caller campaign" do
    it "should do nothing if campaign not changed" do
      campaign = create(:campaign)
      caller = create(:caller, campaign: campaign)
      expect(caller).not_to receive(:is_phones_only?)
      caller.save
    end

    it "should do nothing if campaign changed but caller not logged in" do
      campaign = create(:campaign)
      other_campaign = create(:campaign)
      caller_session = create(:caller_session, on_call: false)
      caller = create(:caller, campaign: campaign)
      caller.update_attributes(campaign_id: other_campaign.id)
      expect(caller_session.reassign_campaign).to eq(CallerSession::ReassignCampaign::NO)
    end

    it "should set on call caller session to reassigned yes" do
      campaign = create(:campaign)
      other_campaign = create(:campaign)
      caller = create(:caller, campaign: campaign, is_phones_only: true)
      caller_session = create(:caller_session, on_call: true, campaign: campaign, caller_id: caller.id)
      caller.update_attributes!(campaign: other_campaign)
      expect(caller_session.reload.reassign_campaign).to eq(CallerSession::ReassignCampaign::YES)
    end

    it "should set on ReassignedCallerSession campaign id" do
      campaign = create(:campaign)
      other_campaign = create(:campaign)
      caller = create(:caller, campaign: campaign, is_phones_only: true)
      caller_session = create(:caller_session, on_call: true, campaign: campaign, caller_id: caller.id)
      caller.update_attributes!(campaign: other_campaign)
      expect(RedisReassignedCallerSession.campaign_id(caller_session.id)).to eq(other_campaign.id.to_s)
    end


  end

  describe "started calling" do

    it "should  push campaign and caller to redis " do
      campaign = create(:predictive)
      caller  = create(:caller, campaign: campaign)
      caller_session = create(:caller_session, caller: caller)
      expect(RedisPredictiveCampaign).to receive(:add).with(campaign.id, campaign.type)
      expect(RedisStatus).to receive(:set_state_changed_time).with(campaign.id, "On hold", caller_session.id)
      caller.started_calling(caller_session)
    end

  end

  describe "calling_voter_preview_power" do
    it "should call pusher and enqueue dial " do
      campaign = create(:predictive)
      caller  = create(:caller, campaign: campaign)
      caller_session = create(:caller_session, caller: caller)
      voter = create(:voter)
      expect(caller).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_calling_voter"])
      expect(caller).to receive(:enqueue_call_flow).with(PreviewPowerDialJob, [caller_session.id, voter.id])
      caller.calling_voter_preview_power(caller_session, voter.id)
    end

  end
end

# ## Schema Information
#
# Table name: `callers`
#
# ### Columns
#
# Name                   | Type               | Attributes
# ---------------------- | ------------------ | ---------------------------
# **`id`**               | `integer`          | `not null, primary key`
# **`name`**             | `string(255)`      |
# **`username`**         | `string(255)`      |
# **`pin`**              | `string(255)`      |
# **`account_id`**       | `integer`          |
# **`active`**           | `boolean`          | `default(TRUE)`
# **`created_at`**       | `datetime`         |
# **`updated_at`**       | `datetime`         |
# **`password`**         | `string(255)`      |
# **`is_phones_only`**   | `boolean`          | `default(FALSE)`
# **`campaign_id`**      | `integer`          |
# **`caller_group_id`**  | `integer`          |
#
