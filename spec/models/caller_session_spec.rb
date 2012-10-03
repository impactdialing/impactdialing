require "spec_helper"

describe CallerSession do
  include Rails.application.routes.url_helpers

  it "lists active callers" do
    call1 = Factory(:caller_session, :on_call=> true)
    call2 = Factory(:caller_session, :on_call=> false)
    call3 = Factory(:caller_session, :on_call=> true)
    CallerSession.on_call.all.should =~ [call1, call3]
  end


  it "lists available caller sessions" do
    call1 = Factory(:caller_session, :available_for_call=> true, :on_call=>true)
    Factory(:caller_session, :available_for_call=> false, :on_call=>false)
    Factory(:caller_session, :available_for_call=> true, :on_call=>false)
    Factory(:caller_session, :available_for_call=> false, :on_call=>false)
    CallerSession.available.should == [call1]
  end

  it "has one attempt in progress" do
    session = Factory(:caller_session)
    attempt = Factory(:call_attempt, :status => CallAttempt::Status::ANSWERED, :caller_session => session)
    current_attempt = Factory(:call_attempt, :status => CallAttempt::Status::INPROGRESS, :caller_session => session)
    new_attempt = Factory(:call_attempt, :status => CallAttempt::Status::INPROGRESS)
    session.update_attributes(attempt_in_progress: new_attempt)
    session.attempt_in_progress.should eq(new_attempt)
  end

  it "has one voter in progress" do
    session = Factory(:caller_session)
    voter = Factory(:voter, :status => CallAttempt::Status::ANSWERED, :caller_session => session)
    current_voter = Factory(:voter, :status => CallAttempt::Status::INPROGRESS, :caller_session => session)
    new_voter = Factory(:voter, :status => CallAttempt::Status::INPROGRESS)
    session.update_attribute(:voter_in_progress, new_voter)
    session.voter_in_progress.should eq(new_voter)
  end



  describe "Calling in" do
    it "puts the caller on hold" do
      session = Factory(:caller_session)
      session.hold.should == Twilio::Verb.new { |v| v.play "#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
    end
  end


  describe "reassigned caller to another campaign" do

    it "should be true" do
      caller = Factory(:caller, :campaign => Factory(:campaign))
      caller_session = Factory(:caller_session, :campaign => Factory(:campaign), :caller => caller)
      caller_session.caller_reassigned_to_another_campaign?.should be_true
    end


    it "reassign the caller_session to campaign" do
      campaign1 = Factory(:preview)
      campaign2 = Factory(:preview)
      caller = Factory(:caller, :campaign => campaign2)
      caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign1, :session_key => "sample", :on_call=> true, :available_for_call => true)
      caller_session.reassign_caller_session_to_campaign
      caller_session.reload.campaign.should == caller.campaign
    end

  end

  describe "monitor" do
    it "should join the moderator into conference and update moderator call_sid" do
      moderator = Factory(:moderator, :session => "monitorsession12")
      session = Factory(:caller_session, :moderator => Factory(:moderator, :call_sid => "123"), :session_key => "gjgdfdkg232hl")
      session.join_conference(true, "123new", "monitorsession12").should == Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true) do
          v.conference("gjgdfdkg232hl", :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "hold_music", :waitMethod =>"GET", :muted => true)
        end
      end.response
      session.moderator.call_sid.should == "123"
    end

    it "should join the moderator into conference and create a moderator with call_sid" do
      moderator = Factory(:moderator, :session => "monitorsession12")
      session = Factory(:caller_session, :session_key => "gjgdfdkg232hl")
      session.join_conference(true, "123", "monitorsession12").should == Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true) do
          v.conference("gjgdfdkg232hl", :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "hold_music", :waitMethod =>"GET", :muted => true)
        end
      end.response
    end

  end

  it "lists attempts between two dates" do
    too_old = Factory(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = Factory(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = Factory(:caller_session).tap { |ca| ca.update_attribute(:created_at, 8.minutes.ago) }
    another_just_right = Factory(:caller_session).tap { |ca| ca.update_attribute(:created_at, 8.minutes.from_now) }
    CallerSession.between(9.minutes.ago, 9.minutes.from_now).should eq([just_right, another_just_right])
  end

  it "sums time caller is logged in" do
    too_old = Factory(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = Factory(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = Factory(:caller_session).tap { |ca| ca.update_attributes(created_at: 8.minutes.ago, starttime: 8.minutes.ago, endtime: 7.minutes.ago ) }
    another_just_right = Factory(:caller_session).tap { |ca| ca.update_attributes(created_at: 8.minutes.from_now, starttime: 8.minutes.ago, endtime: 7.minutes.ago) }
    CallerSession.time_logged_in(nil,nil,9.minutes.ago, 9.minutes.from_now).should eq(120)

  end

  describe "disconnected" do
    it "should say session is disconnected when caller is not available and not on call" do
      session = Factory(:caller_session, session_key: "gjgdfdkg232hl", available_for_call: false, on_call: false)
      session.disconnected?.should be_true
    end

    it "should say session is connected when caller is  available and not on call" do
      session = Factory(:caller_session, session_key: "gjgdfdkg232hl", available_for_call: true, on_call: false)
      session.disconnected?.should be_false
    end

    it "should say session is connected when caller is not available and  on call" do
      session = Factory(:caller_session, session_key: "gjgdfdkg232hl", available_for_call: false, on_call: true)
      session.disconnected?.should be_false
    end

    it "should say session is connected when caller is  available and  on call" do
      session = Factory(:caller_session, session_key: "gjgdfdkg232hl", available_for_call: true, on_call: true)
      session.disconnected?.should be_false
    end


  end

  it "should start a call in initial state" do
    caller_session = Factory(:caller_session)
    caller_session.state.should eq('initial')
  end

  describe "initial state" do

    describe "account not activated" do

      before(:each) do
        @caller = Factory(:caller)
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
      end

      it "should move caller session account not activated state" do
        caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:account_not_activated?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq('account_not_activated')
      end

      it "should render correct twiml" do
        caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:account_not_activated?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Your account has insufficent funds</Say><Hangup/></Response>")
      end

    end

    describe "subscription limit exceeded" do

      before(:each) do
        @account = Factory(:account)
        @caller = Factory(:caller, account: @account)
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
      end

      it "should move caller session subscription limit exceeded state" do
        caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(true)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.start_conf!
        caller_session.state.should eq('subscription_limit')
      end

      it "should render correct twiml" do
        caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(true)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>The maximum number of callers for this account has been reached. Wait for another caller to finish, or ask your administrator to upgrade your account.</Say><Hangup/></Response>")
      end

    end

    describe "Campaign time period exceeded" do

      before(:each) do
        @account = Factory(:account)
        @caller = Factory(:caller, account: @account)
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script,:start_time => Time.new(2011, 1, 1, 9, 0, 0), :end_time => Time.new(2011, 1, 1, 21, 0, 0), :time_zone =>"Pacific Time (US & Canada)")
      end

      it "should move caller session campaign_time_period_exceeded state" do
        caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq('time_period_exceeded')
      end

      it "should render correct twiml" do
        caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 9 AM and 9 PM. Please try back during those hours.</Say><Hangup/></Response>")
      end
    end  
      
   

    describe "Caller already on call" do

      before(:each) do
        @account = Factory(:account)
        @caller = Factory(:caller, account: @account)
        @script = Factory(:script)
        @campaign =  Factory(:campaign, script: @script)
      end

      it "should move caller session caller_on_call state" do
        caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(false)
        caller_session.should_receive(:is_on_call?).and_return(true)
        caller_session.start_conf!
        caller_session.state.should eq('caller_on_call')
      end

      it "should render correct twiml" do
        caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign)
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:account_not_activated?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(false)
        caller_session.should_receive(:is_on_call?).and_return(true)
        caller_session.start_conf!
        caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>Another user is logged in as this caller. Only one user may log in as the same caller at the same time.</Say><Hangup/></Response>")
      end

    end
 end

  describe "conference_ended" do
    before(:each) do
      @caller = Factory(:caller)
      @script = Factory(:script)
      @campaign =  Factory(:campaign, script: @script)
    end

    it "should move caller to end conference from account not activated" do
      caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "account_not_activated")
      caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [{caller_session_id: caller_session.id, event: "publish_caller_disconnected"}])
      caller_session.should_receive(:enqueue_moderator_flow).with(ModeratorCallerJob, [{caller_session_id: caller_session.id, event: "publish_moderator_caller_disconnected"}])
      caller_session.end_conf!
      caller_session.state.should eq('conference_ended')
    end

    it "should make caller unavailable" do
      caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "account_not_activated")
      caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [{caller_session_id: caller_session.id, event: "publish_caller_disconnected"}])
      caller_session.should_receive(:enqueue_moderator_flow).with(ModeratorCallerJob, [{caller_session_id: caller_session.id, event: "publish_moderator_caller_disconnected"}])
      caller_session.end_conf!
      caller_session.on_call.should be_false
      caller_session.available_for_call.should be_false
    end

    it "should set caller session endtime" do
      caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "account_not_activated")
      caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [{caller_session_id: caller_session.id, event: "publish_caller_disconnected"}])
      caller_session.should_receive(:enqueue_moderator_flow).with(ModeratorCallerJob, [{caller_session_id: caller_session.id, event: "publish_moderator_caller_disconnected"}])
      caller_session.end_conf!
      caller_session.endtime.should_not be_nil
    end

    it "should render hangup twiml" do
      caller_session = Factory(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "account_not_activated")
      caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [{caller_session_id: caller_session.id, event: "publish_caller_disconnected"}])
      caller_session.should_receive(:enqueue_moderator_flow).with(ModeratorCallerJob, [{caller_session_id: caller_session.id, event: "publish_moderator_caller_disconnected"}])
      caller_session.end_conf!
      caller_session.render.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end

  end
  
  describe "caller time" do
    it "should return the first caller session for that caller" do
      caller = Factory(:caller)
      caller_session1 = Factory(:caller_session, caller: caller, created_at: 2.hours.ago)
      caller_session2 = Factory(:caller_session, caller: caller, created_at: 4.hours.ago)
      CallerSession.first_caller_time(caller).first.created_at.to_s.should eq(caller_session2.created_at.to_s)
    end
    
    it "should return the last caller session for that caller" do
      caller = Factory(:caller)
      caller_session1 = Factory(:caller_session, caller: caller, created_at: 2.hours.ago)
      caller_session2 = Factory(:caller_session, caller: caller, created_at: 4.hours.ago)
      CallerSession.last_caller_time(caller).first.created_at.to_s.should eq(caller_session1.created_at.to_s)
    end
    
    it "should return the first caller session for that campaign" do
      campaign = Factory(:campaign)
      caller_session1 = Factory(:caller_session, campaign: campaign, created_at: 2.hours.ago)
      caller_session2 = Factory(:caller_session, campaign: campaign, created_at: 4.hours.ago)
      CallerSession.first_campaign_time(campaign).first.created_at.to_s.should eq(caller_session2.created_at.to_s)
    end
    
    it "should return the last caller session for that campaign" do
      campaign = Factory(:campaign)
      caller_session1 = Factory(:caller_session, campaign: campaign, created_at: 2.hours.ago)
      caller_session2 = Factory(:caller_session, campaign: campaign, created_at: 4.hours.ago)
      CallerSession.last_campaign_time(campaign).first.created_at.to_s.should eq(caller_session1.created_at.to_s)
    end
    
    
  end


end