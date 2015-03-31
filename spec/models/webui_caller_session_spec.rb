require 'rails_helper'

describe WebuiCallerSession, :type => :model do
  include Rails.application.routes.url_helpers
  def default_url_options
    {host: 'test.com'}
  end
  describe "initial state" do
    describe "caller moves to connected" do
      before(:each) do
        @account = create(:account)
        @script = create(:script)
        @campaign =  create(:predictive, script: @script)
        @callers_campaign =  create(:predictive, script: @script)
        @caller = create(:caller, campaign: @callers_campaign, account: @account)
      end

      it "should render correct twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(false)
        expect(RedisOnHoldCaller).to receive(:add).with(@campaign.id, caller_session.id)
        expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])

        dial_options = {
          hangupOnStar: true,
          action: pause_caller_url(@caller, session_id: caller_session.id)
        }
        conference_options = {
          startConferenceOnEnter: false,
          endConferenceOnExit: true,
          beep: true,
          waitUrl: 'hold_music',
          waitMethod: 'GET'
        }
        expect(caller_session.start_conf).to dial_conference(dial_options, conference_options)
      end
    end
  end

  describe "connected state" do
    describe "paused" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign)
        @call_attempt = create(:call_attempt, connecttime: Time.now)
      end

      it "when paused should render right twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected",  attempt_in_progress: @call_attempt)
        call_attempt = create(:call_attempt, connecttime: Time.now)
        expect(caller_session.pause).to say("Please enter your call results").and_pause(length: 600)
      end
    end

    describe "connected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:predictive, script: @script)
        @caller = create(:caller, campaign: @campaign, account: create(:account))
        @call_attempt = create(:call_attempt)
      end

      it "should render correct twiml if caller is ready" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", attempt_in_progress: @call_attempt)
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(false)

        expect(RedisOnHoldCaller).to receive(:add).with(@campaign.id,caller_session.id)
        expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])

        dial_options = {
          hangupOnStar: true,
          action: pause_caller_url(@caller, session_id: caller_session.id)
        }
        conference_options = {
          startConferenceOnEnter: false,
          endConferenceOnExit: true,
          beep: true,
          waitUrl: 'hold_music',
          waitMethod: 'GET'
        }
        expect(caller_session.start_conf).to dial_conference(dial_options, conference_options)
      end
    end

    describe "stop calling" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign, account: create(:account))
        @call_attempt = create(:call_attempt)
      end

      it "should end caller session if stop calling" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
        expect(caller_session).to receive(:end_running_call)
        caller_session.stop_calling
      end
    end

    describe "run out of phone numbers" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign, account: create(:account))
        @call_attempt = create(:call_attempt)
      end
      it "should render hangup twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "connected", voter_in_progress: nil)
        expect(caller_session.campaign_out_of_phone_numbers).to say("This campaign has run out of phone numbers.").and_hangup
      end
    end
  end

  describe "paused state" do
    describe "time_period_exceeded" do
      before(:each) do
        @account = create(:account)
        @script = create(:script)
        @campaign =  create(:preview, script: @script,:start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
        @caller = create(:caller, campaign: @campaign, account: @account)
      end

      it "should render correct twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused")
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(true)
        expect(caller_session.start_conf).to say("You can only call this campaign between 9 AM and 9 PM. Please try back during those hours.").and_hangup
      end
    end

    describe "connected" do
      before(:each) do
        @script = create(:script)
        @campaign =  create(:preview, script: @script)
        @caller = create(:caller, campaign: @campaign)
      end

      it "should render correct twiml" do
        caller_session = create(:webui_caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "paused")
        expect(caller_session).to receive(:funds_not_available?).and_return(false)        
        expect(caller_session).to receive(:subscription_limit_exceeded?).and_return(false)
        expect(caller_session).to receive(:time_period_exceeded?).and_return(false)
        expect(caller_session).to receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id, "publish_caller_conference_started"])

        dial_options = {
          hangupOnStar: true,
          action: pause_caller_url(@caller, session_id: caller_session.id)
        }
        conference_options = {
          startConferenceOnEnter: false,
          endConferenceOnExit: true,
          beep: true,
          waitUrl: 'hold_music',
          waitMethod: 'GET'
        }
        expect(caller_session.start_conf).to dial_conference(dial_options, conference_options)
      end
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
