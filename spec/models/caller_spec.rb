require "spec_helper"

describe Caller do
  include Rails.application.routes.url_helpers

  let(:user) { Factory(:user) }
  it "restoring makes it active" do
    caller_object = Factory(:caller, :active => false)
    caller_object.restore
    caller_object.active?.should == true
  end

  it "sorts by the updated date" do
    Caller.record_timestamps = false
    older_caller = Factory(:caller).tap { |c| c.update_attribute(:updated_at, 2.days.ago) }
    newer_caller = Factory(:caller).tap { |c| c.update_attribute(:updated_at, 1.day.ago) }
    Caller.record_timestamps = true
    Caller.by_updated.all.should == [newer_caller, older_caller]
  end

  it "lists active callers" do
    active_caller = Factory(:caller, :active => true)
    inactive_caller = Factory(:caller, :active => false)
    Caller.active.should == [active_caller]
  end

  it "calls in to the campaign" do
    Twilio::REST::Client
    sid = "gogaruko"
    caller = Factory(:caller, :account => user.account)
    campaign = Factory(:campaign, :account => user.account)
    TwilioClient.stub_chain(:instance, :account, :calls, :create).and_return(mock(:response, :sid => sid))
    caller.callin(campaign)
  end

  it "asks for pin" do
    Caller.ask_for_pin.should ==
        Twilio::Verb.new do |v|
          3.times do
            v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :port => Settings.port, :attempt => 1), :method => "POST") do
              v.say "Please enter your pin."
            end
          end
        end.response
  end

  it "asks for pin again" do
    Caller.ask_for_pin(1).should == Twilio::Verb.new do |v|
      3.times do
        v.gather(:numDigits => 5, :timeout => 10, :action => identify_caller_url(:host => Settings.host, :port => Settings.port, :attempt => 2), :method => "POST") do
          v.say "Incorrect Pin. Please enter your pin."
        end
      end
    end.response
  end

  it "is known as the name unless blank" do
    name, mail = 'name', "mail@mail.com"
    web_ui_caller = Factory(:caller, :name => '', :email => mail)
    phones_only_caller = Factory(:caller, :name => name, :email => '')
    web_ui_caller.known_as.should == mail
    phones_only_caller.known_as.should == name
  end

  describe "choice in phones-only" do

    describe "choose voter" do
      before(:each) do
        @campaign = Factory(:campaign, :robo => false, :predictive_type => 'preview', :start_time => (Time.now - 8.hours), :end_time => (Time.now - 8.hours))
        @caller = Factory(:caller, :account => user.account, :campaign => @campaign)
        @caller_session = Factory(:caller_session, :caller => @caller, :campaign => @campaign, :session_key => "sessionkey")
        @voter = Factory(:voter, :campaign => @campaign)
      end

      it "if choice is * , make call to voter and caller will be placed into conference" do
        Twilio::Call.stub(:make)
        Twilio::Call.should_receive(:make).with(anything, @voter.Phone, anything, anything).and_return("TwilioResponse"=> {"Call" => {"Sid" => 'sid'}})
        @caller.choice_result("*", @voter, @caller_session).should == response = Twilio::Verb.new do |v|
          v.dial(:hangupOnStar => true, :action => gather_response_caller_url(@caller, :host => Settings.host, :port => Settings.port, :session_id => @caller_session.id)) do
            v.conference(@caller_session.session_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => 'GET')
          end
        end.response
      end

      it "if choice is # , skip the voter" do
        next_voter = Factory(:voter, :campaign => @campaign, :FirstName => "next voter first name", :LastName => "next voter last name")
        @caller.choice_result("#", @voter, @caller_session).should == Twilio::Verb.new do |v|
          v.gather(:numDigits => 1, :timeout => 10, :action => choose_voter_caller_url(@caller.id, :session => @caller_session.id, :host => Settings.host, :port => Settings.port, :voter => next_voter.id), :method => "POST", :finishOnKey => "5") do
            v.say I18n.t(:read_voter_name, :first_name => next_voter.FirstName, :last_name => next_voter.LastName)
          end
        end.response
        @voter.reload.skipped_time.should_not be_nil
        @voter.reload.status.should == 'not called'
      end

      it "if choice is neither * nor #, agaign ask caller option" do
        @caller.choice_result("3", @voter, @caller_session).should == Twilio::Verb.new do |v|
          v.gather(:numDigits => 1, :timeout => 10, :action => choose_voter_caller_url(@caller, :session => @caller_session, :host => Settings.host, :port => Settings.port, :voter => @voter), :method => "POST", :finishOnKey => "5") do
            v.say I18n.t(:read_star_to_dial_pound_to_skip)
          end
        end.response
      end
    end

    describe "caller instructions" do
      let(:campaign) { Factory(:campaign, :robo => false, :predictive_type => 'preview') }
      let(:caller) { Factory(:caller, :account => user.account, :campaign => campaign) }
      let(:caller_session) { Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sessionkey") }

      it "asks to choose voter if * is chosen" do
        phones_only_caller = Factory(:caller, :is_phones_only => true)
        caller_session.should_receive(:ask_caller_to_choose_voter)
        phones_only_caller.instruction_choice_result("*", caller_session)
      end

      it "puts the caller back into conference when * is chosen" do
        campaign.update_attributes(:predictive_type => 'algorithm1')
        phones_only_caller = Factory(:caller, :is_phones_only => true, :campaign => campaign)
        caller_session = Factory(:caller_session, :caller => phones_only_caller, :campaign => campaign, :session_key => "sessionkey")
        caller_session.should_receive(:start)
        phones_only_caller.instruction_choice_result("*", caller_session)
      end

      it "are read out when # is chosen" do
        caller.instruction_choice_result("#", caller_session).should == Twilio::Verb.new do |v|
          v.gather(:numDigits => 1, :timeout => 10, :action => choose_instructions_option_caller_url(caller, :session => caller_session, :host => Settings.host, :port => Settings.port), :method => "POST", :finishOnKey => "5") do
            v.say I18n.t(:phones_only_caller_instructions)
          end
        end.response
      end

      it "are re-read if chosen input is neither * nor #" do
        caller.instruction_choice_result("4", caller_session).should == Twilio::Verb.new do |v|
          v.gather(:numDigits => 1, :timeout => 10, :action => choose_instructions_option_caller_url(caller, :session => caller_session, :host => Settings.host, :port => Settings.port), :method => "POST", :finishOnKey => "5") do
            v.say I18n.t(:caller_instruction_choice)
          end
        end.response
      end

    end
  end

  it do
    Factory(:caller)
    should validate_uniqueness_of :email
  end

  it "returns name for phone-only-caller, email for web-caller " do
    phones_only_caller = Factory(:caller, :is_phones_only => true, :name => "name", :email => "email1@gmail.com")
    web_caller = Factory(:caller, :is_phones_only => false, :name => "name", :email => "email2@gmail.com")
    phones_only_caller.identity_name.should == "name"
    web_caller.identity_name.should == "email2@gmail.com"
  end

  describe "active session" do
    let(:caller) { Factory(:caller, :account => user.account) }

    it "returns the last available caller session" do
      campaign = Factory(:campaign)
      campaign.callers << caller
      session = Factory(:caller_session, :caller => caller, :session_key => 'key', :on_call => true, :available_for_call => true, :campaign => campaign)
      caller.active_session(campaign).should == session
    end

    it "returns no session if the caller is not available" do
      campaign = Factory(:campaign)
      campaign.callers << caller
      Factory(:caller_session, :caller => caller, :session_key => 'key', :on_call => true, :available_for_call => true, :campaign => Factory(:campaign))
      caller.active_session(campaign).should == {:caller_session => {:id => nil}}
    end

  end

  describe "reports" do
    let(:caller) { Factory(:caller, :account => user.account) }
    let!(:from_time) { 5.minutes.ago }
    let!(:time_now) { Time.now }

    before(:each) do
      Factory(:caller_session, starttime: Time.now, endtime: Time.now + (30.minutes + 2.seconds), :tDuration => 10.minutes + 2.seconds, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      Factory(:caller_session, starttime: Time.now, endtime: Time.now + (101.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (10.minutes + 10.seconds), wrapup_time: Time.now + (10.minutes + 40.seconds), :tDuration => 10.minutes + 2.seconds, :status => CallAttempt::Status::SUCCESS, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::VOICEMAIL, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (101.minutes + 57.seconds), wrapup_time: Time.now + (102.minutes + 57.seconds), :tDuration => 101.minutes + 57.seconds, :status => CallAttempt::Status::SUCCESS, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
      Factory(:call_attempt, connecttime: Time.now, call_end: Time.now + (1.minutes), :tDuration => 1.minutes, :status => CallAttempt::Status::ABANDONED, :caller => caller).tap { |ca| ca.update_attribute(:created_at, from_time) }
    end

    describe "utilization" do
      it "lists time logged in" do
        caller.time_logged_in(from_time, time_now).should == "132"
      end

      it "lists on call time" do
        caller.time_on_call(from_time, time_now).should == "113"
      end

      it "lists on wrapup time" do
        caller.time_in_wrapup(from_time, time_now).should == "2"
      end

      it "lists on hold time" do
        caller.time_onhold(from_time, time_now) == "19"
      end

    end

    describe "billing" do
      it "lists caller time" do
        caller.caller_time(from_time, time_now).should == 133
      end

      it "lists lead time" do
        caller.lead_time(from_time, time_now).should == 113
      end
    end

    describe "campaign" do

      let(:voter) { Factory(:voter) }
      let(:question) { Factory(:question, :text => "what?", :script => Factory(:script)) }

      it "gets stats for answered calls" do
        response_1 = Factory(:possible_response, :value => "foo")
        response_2 = Factory(:possible_response, :value => "bar")
        campaign = Factory(:campaign)
        3.times { Factory(:answer, :caller => caller, :voter => voter, :question => question, :possible_response => response_1, :campaign => campaign) }
        2.times { Factory(:answer, :caller => caller, :voter => voter, :question => question, :possible_response => response_2, :campaign => campaign) }
        Factory(:answer, :caller => caller, :voter => voter, :question => question, :possible_response => response_1, :campaign => Factory(:campaign))
        stats = caller.answered_call_stats(from_time, time_now, campaign.id)
        stats.should == {"what?" => {
          :total => {:count => 5, :percentage => 100},
          "foo" => {:count => 3, :percentage => 60},
          "bar" => {:count => 2, :percentage => 40},
        }}
      end
    end
  end
end
