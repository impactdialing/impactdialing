require "spec_helper"

describe CallerSession, :type => :model do
  before do
    WebMock.disable_net_connect!
  end
  include Rails.application.routes.url_helpers
  it "lists available caller sessions" do
    caller_session1 = create(:caller_session, on_call: true, available_for_call: false)
    caller_session2 = create(:webui_caller_session, on_call: true, available_for_call: true)
    caller_session3 = create(:webui_caller_session, on_call: true, available_for_call: false)
    caller_session4 = create(:phones_only_caller_session, on_call: true, available_for_call: true)
    caller_session5 = create(:phones_only_caller_session, on_call: true, available_for_call: true)

    expect(CallerSession.available).to include(caller_session2, caller_session4, caller_session5)
  end

  it "has one attempt in progress" do
    session = create(:caller_session)
    attempt = create(:call_attempt, :status => CallAttempt::Status::ANSWERED, :caller_session => session)
    current_attempt = create(:call_attempt, :status => CallAttempt::Status::INPROGRESS, :caller_session => session)
    new_attempt = create(:call_attempt, :status => CallAttempt::Status::INPROGRESS)
    session.update_attributes(attempt_in_progress: new_attempt)
    expect(session.attempt_in_progress).to eq(new_attempt)
  end

  it "has one voter in progress" do
    session = create(:caller_session)
    voter = create(:voter, :status => CallAttempt::Status::ANSWERED, :caller_session => session)
    current_voter = create(:voter, :status => CallAttempt::Status::INPROGRESS, :caller_session => session)
    new_voter = create(:voter, :status => CallAttempt::Status::INPROGRESS)
    session.update_attribute(:voter_in_progress, new_voter)
    expect(session.voter_in_progress).to eq(new_voter)
  end

  describe "Calling in" do
    it "puts the caller on hold" do
      session = create(:caller_session)
      expect(session.hold).to eq(Twilio::Verb.new { |v| v.play "#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response)
    end
  end

  describe "reassigned caller to another campaign" do
    it "should be true" do
      caller = create(:caller, :campaign => create(:campaign))
      caller_session = create(:caller_session, campaign: create(:campaign), caller: caller, reassign_campaign: CallerSession::ReassignCampaign::YES)
      expect(caller_session.reassigned_to_another_campaign?).to be_truthy
    end

    it "handle reassign the caller_session to campaign should set reassign campaign to DONE" do
      campaign1 = create(:preview)
      campaign2 = create(:preview)
      caller = create(:caller, :campaign => campaign2)
      caller_session = create(:caller_session, :caller => caller, :campaign => campaign1, :session_key => "sample",
        :on_call=> true, :available_for_call => true, reassign_campaign: CallerSession::ReassignCampaign::YES)
      RedisReassignedCallerSession.set_campaign_id(caller_session.id, campaign2.id)
      caller_session.handle_reassign_campaign
      expect(caller_session.reload.reassign_campaign).to eq(CallerSession::ReassignCampaign::DONE)
    end

    it "handle reassign the caller_session to campaign should set new campaign id" do
      campaign1 = create(:preview)
      campaign2 = create(:preview)
      caller = create(:caller, :campaign => campaign1)
      caller_session = create(:caller_session, :caller => caller, :campaign => campaign1, :session_key => "sample",
        :on_call=> true, :available_for_call => true, reassign_campaign: CallerSession::ReassignCampaign::YES)
      RedisReassignedCallerSession.set_campaign_id(caller_session.id, campaign2.id)
      caller_session.handle_reassign_campaign
      expect(caller_session.reload.campaign_id).to eq(campaign2.id)
    end

    it "handle reassign the caller_session to campaign should delete new campaign id from redis" do
      campaign1 = create(:preview)
      campaign2 = create(:preview)
      caller = create(:caller, :campaign => campaign2)
      caller_session = create(:caller_session, :caller => caller, :campaign => campaign1, :session_key => "sample",
        :on_call=> true, :available_for_call => true, reassign_campaign: CallerSession::ReassignCampaign::YES)
      RedisReassignedCallerSession.set_campaign_id(caller_session.id, campaign2.id)
      expect(RedisReassignedCallerSession).to receive(:delete).with(caller_session.id)
      caller_session.handle_reassign_campaign
    end
  end

  describe "monitor" do
    it "should join the moderator into conference and update moderator call_sid" do
      moderator = create(:moderator, :session => "monitorsession12")
      session = create(:caller_session, :moderator => create(:moderator, :call_sid => "123"), :session_key => "gjgdfdkg232hl")
      expect(session.join_conference(true)).to eq(Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true) do
          v.conference("gjgdfdkg232hl", :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "hold_music", :waitMethod =>"GET", :muted => true)
        end
      end.response)
      expect(session.moderator.call_sid).to eq("123")
    end

    it "should join the moderator into conference and create a moderator with call_sid" do
      moderator = create(:moderator, :session => "monitorsession12")
      session = create(:caller_session, :session_key => "gjgdfdkg232hl")
      expect(session.join_conference(true)).to eq(Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true) do
          v.conference("gjgdfdkg232hl", :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "hold_music", :waitMethod =>"GET", :muted => true)
        end
      end.response)
    end
  end

  it "lists attempts between two dates" do
    too_old = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 8.minutes.ago) }
    another_just_right = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 8.minutes.from_now) }
    expect(CallerSession.between(9.minutes.ago, 9.minutes.from_now)).to include(just_right)
    expect(CallerSession.between(9.minutes.ago, 9.minutes.from_now)).to include(another_just_right)
  end

  it "sums time caller is logged in" do
    too_old = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = create(:caller_session).tap { |ca| ca.update_attributes(created_at: 8.minutes.ago, tStartTime: 8.minutes.ago, tEndTime: 7.minutes.ago, tDuration: 60) }
    another_just_right = create(:caller_session).tap { |ca| ca.update_attributes(created_at: 8.minutes.from_now, tStartTime: 8.minutes.ago, tEndTime: 7.minutes.ago,  tDuration: 60) }
    expect(CallerSession.time_logged_in(nil,nil,9.minutes.ago, 9.minutes.from_now)).to eq(120)
  end

  describe "disconnected" do
    it "should say session is disconnected when conference ended" do
      call_attempt = create(:call_attempt)
      campaign = create(:campaign)
      caller_session = create(:caller_session, on_call: false, available_for_call: false, attempt_in_progress: call_attempt, campaign: campaign,state: "conference_ended")
      expect(caller_session.disconnected?).to be_truthy
    end
  end

  it "should start a call in initial state" do
    caller_session = create(:caller_session)
    expect(caller_session.state).to eq('initial')
  end

  describe "initial state" do
    describe "subscription limit exceeded" do
      before(:each) do
        @account = create(:account)
        @caller = create(:caller, account: @account)
        @script = create(:script)
        @campaign =  create(:campaign, script: @script)
      end

      it "should render correct twiml" do
        caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        expect(caller_session).to receive(:funds_not_available?).and_return(false)
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(true)
        expect(caller_session.start_conf).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>The maximum number of callers for this account has been reached. Wait for another caller to finish, or ask your administrator to upgrade your account.</Say><Hangup/></Response>")
      end
    end

    describe "Campaign time period exceeded" do
      before(:each) do
        @account = create(:account)
        @caller = create(:caller, account: @account)
        @script = create(:script)
        @campaign =  create(:campaign, script: @script,:start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
      end

      it "should render correct twiml" do
        caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        expect(caller_session).to receive(:funds_not_available?).and_return(false)
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(true)
        expect(caller_session.start_conf).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 9 AM and 9 PM. Please try back during those hours.</Say><Hangup/></Response>")
      end
    end
  end

  describe "conference_ended" do
    before(:each) do
      @caller = create(:caller)
      @script = create(:script)
      @campaign =  create(:campaign, script: @script)
      @call_attempt = create(:call_attempt)
    end

    it "should set caller session endtime" do
      caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "account_not_activated")
      expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id,  "publish_caller_disconnected"])
      caller_session.conference_ended
      expect(caller_session.endtime).not_to be_nil
    end

    it "should render hangup twiml" do
      caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "account_not_activated")
      expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id,  "publish_caller_disconnected"])
      expect(caller_session.conference_ended).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end
  end

  describe "end_running_call" do
    it "should end call" do
      caller = create(:caller)
      caller_session = create(:caller_session, caller: caller)
      expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, 'publish_caller_disconnected'])
      expect(caller_session).to receive(:enqueue_call_flow).with(EndRunningCallJob, [caller_session.sid])
      expect(caller_session).to receive(:enqueue_call_flow).with(EndCallerSessionJob, [caller_session.id])
      caller_session.end_running_call
      expect(caller_session.endtime).not_to be_nil
    end
  end

  describe "caller time" do
    it "should return the first caller session for that caller" do
      caller = create(:caller)
      caller_session1 = create(:caller_session, caller: caller, created_at: 2.hours.ago)
      caller_session2 = create(:caller_session, caller: caller, created_at: 4.hours.ago)
      expect(CallerSession.first_caller_time(caller).first.created_at.to_s).to eq(caller_session2.created_at.to_s)
    end

    it "should return the last caller session for that caller" do
      caller = create(:caller)
      caller_session1 = create(:caller_session, caller: caller, created_at: 2.hours.ago)
      caller_session2 = create(:caller_session, caller: caller, created_at: 4.hours.ago)
      expect(CallerSession.last_caller_time(caller).first.created_at.to_s).to eq(caller_session1.created_at.to_s)
    end

    it "should return the first caller session for that campaign" do
      campaign = create(:campaign)
      caller_session1 = create(:caller_session, campaign: campaign, created_at: 2.hours.ago)
      caller_session2 = create(:caller_session, campaign: campaign, created_at: 4.hours.ago)
      expect(CallerSession.first_campaign_time(campaign).first.created_at.to_s).to eq(caller_session2.created_at.to_s)
    end

    it "should return the last caller session for that campaign" do
      campaign = create(:campaign)
      caller_session1 = create(:caller_session, campaign: campaign, created_at: 2.hours.ago)
      caller_session2 = create(:caller_session, campaign: campaign, created_at: 4.hours.ago)
      expect(CallerSession.last_campaign_time(campaign).first.created_at.to_s).to eq(caller_session1.created_at.to_s)
    end
  end
end

# ## Schema Information
#
# Table name: `caller_sessions`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`caller_id`**             | `integer`          |
# **`campaign_id`**           | `integer`          |
# **`endtime`**               | `datetime`         |
# **`starttime`**             | `datetime`         |
# **`sid`**                   | `string(255)`      |
# **`available_for_call`**    | `boolean`          | `default(FALSE)`
# **`voter_in_progress_id`**  | `integer`          |
# **`created_at`**            | `datetime`         |
# **`updated_at`**            | `datetime`         |
# **`on_call`**               | `boolean`          | `default(FALSE)`
# **`caller_number`**         | `string(255)`      |
# **`tCallSegmentSid`**       | `string(255)`      |
# **`tAccountSid`**           | `string(255)`      |
# **`tCalled`**               | `string(255)`      |
# **`tCaller`**               | `string(255)`      |
# **`tPhoneNumberSid`**       | `string(255)`      |
# **`tStatus`**               | `string(255)`      |
# **`tDuration`**             | `integer`          |
# **`tFlags`**                | `integer`          |
# **`tStartTime`**            | `datetime`         |
# **`tEndTime`**              | `datetime`         |
# **`tPrice`**                | `float`            |
# **`attempt_in_progress`**   | `integer`          |
# **`session_key`**           | `string(255)`      |
# **`state`**                 | `string(255)`      |
# **`type`**                  | `string(255)`      |
# **`digit`**                 | `string(255)`      |
# **`debited`**               | `boolean`          | `default(FALSE)`
# **`question_id`**           | `integer`          |
# **`caller_type`**           | `string(255)`      |
# **`question_number`**       | `integer`          |
# **`script_id`**             | `integer`          |
# **`reassign_campaign`**     | `string(255)`      | `default("no")`
#
# ### Indexes
#
# * `index_caller_sessions_debit`:
#     * **`debited`**
#     * **`caller_type`**
#     * **`tStartTime`**
#     * **`tEndTime`**
#     * **`tDuration`**
# * `index_caller_sessions_on_caller_id`:
#     * **`caller_id`**
# * `index_caller_sessions_on_campaign_id`:
#     * **`campaign_id`**
# * `index_caller_sessions_on_sid`:
#     * **`sid`**
# * `index_callers_on_call_group_by_campaign`:
#     * **`campaign_id`**
#     * **`on_call`**
# * `index_state_caller_sessions`:
#     * **`state`**
#
