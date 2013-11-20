require "spec_helper"

WebMock.disable_net_connect!

describe CallerSession do
  include Rails.application.routes.url_helpers
  it "lists available caller sessions" do
    caller_session1 = create(:caller_session, on_call: true, available_for_call: false)
    caller_session2 = create(:webui_caller_session, on_call: true, available_for_call: true)
    caller_session3 = create(:webui_caller_session, on_call: true, available_for_call: false)
    caller_session4 = create(:phones_only_caller_session, on_call: true, available_for_call: true)
    caller_session5 = create(:phones_only_caller_session, on_call: true, available_for_call: true)

    CallerSession.available.should include(caller_session2, caller_session4, caller_session5)
  end

  it "has one attempt in progress" do
    session = create(:caller_session)
    attempt = create(:call_attempt, :status => CallAttempt::Status::ANSWERED, :caller_session => session)
    current_attempt = create(:call_attempt, :status => CallAttempt::Status::INPROGRESS, :caller_session => session)
    new_attempt = create(:call_attempt, :status => CallAttempt::Status::INPROGRESS)
    session.update_attributes(attempt_in_progress: new_attempt)
    session.attempt_in_progress.should eq(new_attempt)
  end

  it "has one voter in progress" do
    session = create(:caller_session)
    voter = create(:voter, :status => CallAttempt::Status::ANSWERED, :caller_session => session)
    current_voter = create(:voter, :status => CallAttempt::Status::INPROGRESS, :caller_session => session)
    new_voter = create(:voter, :status => CallAttempt::Status::INPROGRESS)
    session.update_attribute(:voter_in_progress, new_voter)
    session.voter_in_progress.should eq(new_voter)
  end

  describe "Calling in" do
    it "puts the caller on hold" do
      session = create(:caller_session)
      session.hold.should == Twilio::Verb.new { |v| v.play "#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
    end
  end

  describe "reassigned caller to another campaign" do
    it "should be true" do
      caller = create(:caller, :campaign => create(:campaign))
      caller_session = create(:caller_session, campaign: create(:campaign), caller: caller, reassign_campaign: CallerSession::ReassignCampaign::YES)
      caller_session.reassigned_to_another_campaign?.should be_true
    end

    it "handle reassign the caller_session to campaign should set reassign campaign to DONE" do
      campaign1 = create(:preview)
      campaign2 = create(:preview)
      caller = create(:caller, :campaign => campaign2)
      caller_session = create(:caller_session, :caller => caller, :campaign => campaign1, :session_key => "sample",
        :on_call=> true, :available_for_call => true, reassign_campaign: CallerSession::ReassignCampaign::YES)
      RedisReassignedCallerSession.set_campaign_id(caller_session.id, campaign2.id)
      caller_session.handle_reassign_campaign
      caller_session.reload.reassign_campaign.should == CallerSession::ReassignCampaign::DONE
    end

    it "handle reassign the caller_session to campaign should set new campaign id" do
      campaign1 = create(:preview)
      campaign2 = create(:preview)
      caller = create(:caller, :campaign => campaign1)
      caller_session = create(:caller_session, :caller => caller, :campaign => campaign1, :session_key => "sample",
        :on_call=> true, :available_for_call => true, reassign_campaign: CallerSession::ReassignCampaign::YES)
      RedisReassignedCallerSession.set_campaign_id(caller_session.id, campaign2.id)
      caller_session.handle_reassign_campaign
      caller_session.reload.campaign_id.should eq(campaign2.id)
    end

    it "handle reassign the caller_session to campaign should delete new campaign id from redis" do
      campaign1 = create(:preview)
      campaign2 = create(:preview)
      caller = create(:caller, :campaign => campaign2)
      caller_session = create(:caller_session, :caller => caller, :campaign => campaign1, :session_key => "sample",
        :on_call=> true, :available_for_call => true, reassign_campaign: CallerSession::ReassignCampaign::YES)
      RedisReassignedCallerSession.set_campaign_id(caller_session.id, campaign2.id)
      RedisReassignedCallerSession.should_receive(:delete).with(caller_session.id)
      caller_session.handle_reassign_campaign
    end
  end

  describe "monitor" do
    it "should join the moderator into conference and update moderator call_sid" do
      moderator = create(:moderator, :session => "monitorsession12")
      session = create(:caller_session, :moderator => create(:moderator, :call_sid => "123"), :session_key => "gjgdfdkg232hl")
      session.join_conference(true).should == Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true) do
          v.conference("gjgdfdkg232hl", :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "hold_music", :waitMethod =>"GET", :muted => true)
        end
      end.response
      session.moderator.call_sid.should == "123"
    end

    it "should join the moderator into conference and create a moderator with call_sid" do
      moderator = create(:moderator, :session => "monitorsession12")
      session = create(:caller_session, :session_key => "gjgdfdkg232hl")
      session.join_conference(true).should == Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true) do
          v.conference("gjgdfdkg232hl", :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "hold_music", :waitMethod =>"GET", :muted => true)
        end
      end.response
    end
  end

  it "lists attempts between two dates" do
    too_old = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 8.minutes.ago) }
    another_just_right = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 8.minutes.from_now) }
    CallerSession.between(9.minutes.ago, 9.minutes.from_now).should include(just_right)
    CallerSession.between(9.minutes.ago, 9.minutes.from_now).should include(another_just_right)
  end

  it "sums time caller is logged in" do
    too_old = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.ago) }
    too_new = create(:caller_session).tap { |ca| ca.update_attribute(:created_at, 10.minutes.from_now) }
    just_right = create(:caller_session).tap { |ca| ca.update_attributes(created_at: 8.minutes.ago, tStartTime: 8.minutes.ago, tEndTime: 7.minutes.ago, tDuration: 60) }
    another_just_right = create(:caller_session).tap { |ca| ca.update_attributes(created_at: 8.minutes.from_now, tStartTime: 8.minutes.ago, tEndTime: 7.minutes.ago,  tDuration: 60) }
    CallerSession.time_logged_in(nil,nil,9.minutes.ago, 9.minutes.from_now).should eq(120)
  end

  describe "disconnected" do
    it "should say session is disconnected when conference ended" do
      call_attempt = create(:call_attempt)
      campaign = create(:campaign)
      caller_session = create(:caller_session, on_call: false, available_for_call: false, attempt_in_progress: call_attempt, campaign: campaign,state: "conference_ended")
      caller_session.disconnected?.should be_true
    end
  end

  it "should start a call in initial state" do
    caller_session = create(:caller_session)
    caller_session.state.should eq('initial')
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
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(true)
        caller_session.start_conf.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>The maximum number of callers for this account has been reached. Wait for another caller to finish, or ask your administrator to upgrade your account.</Say><Hangup/></Response>")
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
        caller_session.should_receive(:funds_not_available?).and_return(false)
        caller_session.should_receive(:subscription_limit_exceeded?).and_return(false)
        caller_session.should_receive(:time_period_exceeded?).and_return(true)
        caller_session.start_conf.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say>You can only call this campaign between 9 AM and 9 PM. Please try back during those hours.</Say><Hangup/></Response>")
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
      caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id,  "publish_caller_disconnected"])
      caller_session.conference_ended
      caller_session.endtime.should_not be_nil
    end

    it "should render hangup twiml" do
      caller_session = create(:caller_session, caller: @caller, on_call: true, available_for_call: true, campaign: @campaign, state: "account_not_activated")
      caller_session.should_receive(:enqueue_call_flow).with(CallerPusherJob, [caller_session.id,  "publish_caller_disconnected"])
      caller_session.conference_ended.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    end
  end

  describe "end_running_call" do
    it "should end call" do
      caller = create(:caller)
      caller_session = create(:caller_session, caller: caller)
      caller_session.should_receive(:enqueue_call_flow).with(EndRunningCallJob, [caller_session.sid])
      caller_session.should_receive(:enqueue_call_flow).with(EndCallerSessionJob, [caller_session.id])
      caller_session.end_running_call
      caller_session.endtime.should_not be_nil
    end
  end

  describe "caller time" do
    it "should return the first caller session for that caller" do
      caller = create(:caller)
      caller_session1 = create(:caller_session, caller: caller, created_at: 2.hours.ago)
      caller_session2 = create(:caller_session, caller: caller, created_at: 4.hours.ago)
      CallerSession.first_caller_time(caller).first.created_at.to_s.should eq(caller_session2.created_at.to_s)
    end

    it "should return the last caller session for that caller" do
      caller = create(:caller)
      caller_session1 = create(:caller_session, caller: caller, created_at: 2.hours.ago)
      caller_session2 = create(:caller_session, caller: caller, created_at: 4.hours.ago)
      CallerSession.last_caller_time(caller).first.created_at.to_s.should eq(caller_session1.created_at.to_s)
    end

    it "should return the first caller session for that campaign" do
      campaign = create(:campaign)
      caller_session1 = create(:caller_session, campaign: campaign, created_at: 2.hours.ago)
      caller_session2 = create(:caller_session, campaign: campaign, created_at: 4.hours.ago)
      CallerSession.first_campaign_time(campaign).first.created_at.to_s.should eq(caller_session2.created_at.to_s)
    end

    it "should return the last caller session for that campaign" do
      campaign = create(:campaign)
      caller_session1 = create(:caller_session, campaign: campaign, created_at: 2.hours.ago)
      caller_session2 = create(:caller_session, campaign: campaign, created_at: 4.hours.ago)
      CallerSession.last_campaign_time(campaign).first.created_at.to_s.should eq(caller_session1.created_at.to_s)
    end
  end

  describe 'redirecting callers' do
    def encode(str)
      URI.encode_www_form_component(str)
    end
    def request_body(url)
      "CurrentUrl=#{encode(url)}&CurrentMethod=POST"
    end
    let(:caller) do
      create(:caller)
    end
    let(:caller_session) do
      create(:caller_session, {
        caller: caller
      })
    end
    let(:twilio_url) do
      "api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}/Calls/#{caller_session.sid}"
    end

    let(:url_opts) do
      {
        :host => DataCentre.call_back_host(caller_session.data_centre),
        :port => Settings.twilio_callback_port,
        :protocol => "http://",
        session_id: caller_session.id
      }
    end
    context 'to call more leads' do
      context 'caller is phones only' do
        before do
          caller.update_attribute(:is_phones_only, true)
          url = ready_to_call_caller_url(caller_session.caller_id, url_opts)
          @request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                      with(:body => request_body(url))
        end

        it 'redirects caller to ready_to_call_caller_url' do
          response = caller_session.redirect_caller
          @request.should have_been_made
        end
      end

      context 'caller is not phones only' do
        before do
          url = continue_conf_caller_url(caller_session.caller_id, url_opts)
          @request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                      with(:body => request_body(url))
        end

        it 'redirects caller to continue_conf_caller_url' do
          caller_session.redirect_caller
          @request.should have_been_made
        end
      end
    end

    context 'when caller is available for call and campaign type is not predictive' do
      after do
        @request.should have_been_made
      end
      it 'can redirect caller to run_out_of_numbers_caller_url' do
        url = run_out_of_numbers_caller_url(caller_session.caller_id, url_opts)
        @request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                    with(:body => request_body(url))
        caller_session.redirect_caller_out_of_numbers
      end

      it 'can redirect caller to time_period_exceeded_caller_url' do
        url = time_period_exceeded_caller_url(caller_session.caller_id, url_opts)
        @request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                    with(:body => request_body(url))
        caller_session.redirect_caller_time_period_exceeded
      end

      it 'can redirect caller to account_out_of_funds_caller_url' do
        url = account_out_of_funds_caller_url(caller_session.caller_id, url_opts)
        @request = stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
                    with(:body => request_body(url))
        caller_session.redirect_account_has_no_funds
      end
    end
  end
end