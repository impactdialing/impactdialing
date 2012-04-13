require "spec_helper"

describe CallerSession do
  include Rails.application.routes.url_helpers

  it "lists active callers" do
    call1 = Factory(:caller_session, :on_call=> true)
    call2 = Factory(:caller_session, :on_call=> false)
    call3 = Factory(:caller_session, :on_call=> true)
    CallerSession.on_call.all.should =~ [call1, call3]
  end

  it "lists callers with hold for duration" do
    Factory(:caller_session, :on_call=> false, :hold_time_start=> Time.now)
    Factory(:caller_session, :on_call=> true, :hold_time_start=> Time.now)
    call3 = Factory(:caller_session, :on_call=> false, :hold_time_start=> 3.minutes.ago)
    call4 = Factory(:caller_session, :on_call=> false, :hold_time_start=> 6.minutes.ago)
    CallerSession.held_for_duration(3.minutes).should == [call3, call4]
  end

  it "lists available caller sessions" do
    call1 = Factory(:caller_session, :available_for_call=> true, :on_call=>true)
    Factory(:caller_session, :available_for_call=> false, :on_call=>false)
    Factory(:caller_session, :available_for_call=> true, :on_call=>false)
    Factory(:caller_session, :available_for_call=> false, :on_call=>false)
    CallerSession.available.should == [call1]
  end

  xit "has one attempt in progress" do
    session = Factory(:caller_session)
    attempt = Factory(:call_attempt, :status => CallAttempt::Status::ANSWERED, :caller_session => session)
    current_attempt = Factory(:call_attempt, :status => CallAttempt::Status::INPROGRESS, :caller_session => session)
    new_attempt = Factory(:call_attempt, :status => CallAttempt::Status::INPROGRESS)
    session.update_attribute(:attempt_in_progress, new_attempt)
    current_attempt.reload.caller_session.should be_nil
    attempt.reload.caller_session.should == session
    new_attempt.reload.caller_session.should == session
  end

  xit "has one voter in progress" do
    session = Factory(:caller_session)
    voter = Factory(:voter, :status => CallAttempt::Status::ANSWERED, :caller_session => session)
    current_voter = Factory(:voter, :status => CallAttempt::Status::INPROGRESS, :caller_session => session)
    new_voter = Factory(:voter, :status => CallAttempt::Status::INPROGRESS)
    session.update_attribute(:voter_in_progress, new_voter)
    current_voter.reload.caller_session.should be_nil
    voter.reload.caller_session.should == session
    new_voter.reload.caller_session.should == session
  end

  it "calls a voter" do
    voter = Factory(:voter, :campaign => Factory(:campaign, :predictive_type => 'algorithm1'))
    session = Factory(:caller_session, :available_for_call => true, :on_call => false)
    Twilio::Call.stub!(:make).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})
    voter.should_receive(:dial_predictive)
    session.call(voter)
    voter.caller_session.should == session
  end

  it "sets an the last call attempted on a caller session as the attempt in progress" do
    caller_session = Factory(:caller_session)
    first_attempt = Factory(:call_attempt, :caller_session => caller_session)
    caller_session.update_attributes(:attempt_in_progress => nil)
    latest_attempt = Factory(:call_attempt, :caller_session => caller_session, :status => CallAttempt::Status::INPROGRESS)
    caller_session.attempt_in_progress.should == latest_attempt
  end

  describe "Calling in" do
    it "creates a conference" do
      campaign, conf_key = Factory(:campaign), "conference_key"
      caller = Factory(:caller, campaign: campaign)
      session = Factory(:caller_session, caller: caller, campaign: campaign, session_key: conf_key)
      campaign.stub!(:time_period_exceed?).and_return(false)
      session.stub!(:caller_reassigned_to_another_campaign?).and_return(false)
      session.start.should == Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true, :action => session.send(:caller_response_path)) do
          v.conference(conf_key, :startConferenceOnEnter => false, :endConferenceOnExit => true, :beep => true, :waitUrl => hold_call_url(:host => Settings.host, :port => Settings.port, :version => HOLD_VERSION), :waitMethod => "GET")
        end
      end.response
      session.on_call.should be_true
      session.available_for_call.should be_true
    end

    it "terminates a conference" do
      campaign, conf_key = Factory(:campaign), "conference_key"
      caller = Factory(:caller, campaign: campaign)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => conf_key)
      time_now = Time.now
      Moderator.stub!(:publish_event).with(session.campaign, 'caller_disconnected', {:caller_session_id => session.id, :caller_id => session.caller.id, :campaign_id => campaign.id,
                                                                                     :campaign_active => false, :no_of_callers_logged_in => 0})
      Time.stub(:now).and_return(time_now)
      response = session.end
      response.should == Twilio::Verb.hangup
      session.available_for_call.should be_false
      session.on_call.should be_false
      session.endtime.should == time_now
    end

    it "puts the caller on hold" do
      session = Factory(:caller_session)
      session.hold.should == Twilio::Verb.new { |v| v.play "#{Settings.host}:#{Settings.port}/wav/hold.mp3"; v.redirect(:method => 'GET'); }.response
    end

    it "reads responses to a phones only caller" do
      caller = Factory(:caller, :is_phones_only => true, :name => 'me')
      caller_session = Factory(:caller_session, :caller => caller)
      caller_session.send(:caller_response_path).should == gather_response_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => caller_session.id)
    end

    it "prompts  for response to a caller using the web ui" do
      caller = Factory(:caller, :email => 'me@i.com')
      caller_session = Factory(:caller_session, :caller => caller)
      caller_session.send(:caller_response_path).should == pause_caller_url(caller, :host => Settings.host, :port => Settings.port, :session_id => caller_session.id)
    end
  end

  describe "preview dialing" do
    let(:campaign) { Factory(:campaign, :robo => false, :predictive_type => 'preview', answering_machine_detect: true) }
    let(:voter) { Factory(:voter, :campaign => campaign) }
    let(:caller) { Factory(:caller) }

    it "dials a voter for a caller session" do
      caller_session = Factory(:caller_session, :campaign => campaign, :caller => caller, :attempt_in_progress => nil)
      call_attempt = Factory(:call_attempt, :campaign => campaign, :dialer_mode => Campaign::Type::PREVIEW, :status => CallAttempt::Status::INPROGRESS, :caller_session => caller_session, :caller => caller)
      voter.stub_chain(:call_attempts, :create).and_return(call_attempt)
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, connect_call_attempt_url(call_attempt, :host => Settings.host, :port => Settings.port), {"FallbackUrl"=>"blah", 'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})

      caller_session.preview_dial(voter)
      voter.caller_session.should == caller_session
      caller_session.reload.attempt_in_progress.should == call_attempt
      call_attempt.sid.should == "sid"
      call_attempt.caller.should_not be_nil
    end

    it "catches exception and pushes next voter if call cannot be made" do
      caller_session = Factory(:caller_session, :campaign => campaign, :caller => caller, :attempt_in_progress => nil)
      call_attempt = Factory(:call_attempt, :campaign => campaign, :dialer_mode => Campaign::Type::PREVIEW, :status => CallAttempt::Status::INPROGRESS, :caller_session => caller_session, :caller => caller)
      voter.stub_chain(:call_attempts, :create).and_return(call_attempt)
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, connect_call_attempt_url(call_attempt, :host => Settings.host, :port => Settings.port), {"FallbackUrl"=>"blah", 'StatusCallback'=> anything, 'IfMachine' => 'Continue', 'Timeout' => anything}).and_return({"TwilioResponse" => {"RestException" => {"Status" => "400"}}})
      channel = mock
      Pusher.should_receive(:[]).with(caller_session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("call_could_not_connect", anything)
      caller_session.preview_dial(voter)
      call_attempt.status.should eq(CallAttempt::Status::FAILED)
      voter.status.should eq(CallAttempt::Status::FAILED)
    end


    it "does not send IFMachine if AMD turned off" do
      campaign1 = Factory(:campaign, :robo => false, :predictive_type => 'preview', answering_machine_detect: false)
      caller_session = Factory(:caller_session, :campaign => campaign1, :caller => caller, :attempt_in_progress => nil)
      call_attempt = Factory(:call_attempt, :campaign => campaign1, :dialer_mode => Campaign::Type::PREVIEW, :status => CallAttempt::Status::INPROGRESS, :caller_session => caller_session, :caller => caller)
      voter.stub_chain(:call_attempts, :create).and_return(call_attempt)
      Twilio::Call.should_receive(:make).with(anything, voter.Phone, connect_call_attempt_url(call_attempt, :host => Settings.host, :port => Settings.port), {"FallbackUrl"=>"blah", 'StatusCallback'=> anything, 'Timeout' => anything}).and_return({"TwilioResponse" => {"Call" => {"Sid" => "sid"}}})

      caller_session.preview_dial(voter)
      voter.caller_session.should == caller_session
      caller_session.reload.attempt_in_progress.should == call_attempt
      call_attempt.sid.should == "sid"
      call_attempt.caller.should_not be_nil

    end

    it "pauses the voters results to be entered by the caller" do
      caller_session = Factory(:caller_session, :caller => caller)
      caller_session.pause_for_results.should == Twilio::Verb.new { |v| v.say("Please enter your call results"); v.pause("length" => 30); v.redirect(pause_caller_url(caller, :session_id => caller_session.id, :host => Settings.host, :port => Settings.port, :attempt => 1)) }.response
    end

    it "pause for results triggers pusher in the first attempt" do
      caller_session = Factory(:caller_session, :caller => caller)
      caller_session.should_receive(:publish)
      caller_session.pause_for_results
    end

    it "pause for results does not send pusher events in subsequent attempts" do
      caller_session = Factory(:caller_session, :caller => caller)
      caller_session.should_not_receive(:publish)
      caller_session.pause_for_results(1)
    end

    it "says wait message only on every fifth pause redirect" do
      caller_session = Factory(:caller_session, :caller => caller)
      caller_session.pause_for_results.should == Twilio::Verb.new { |v| v.say("Please enter your call results"); v.pause("length" => 30); v.redirect(pause_caller_url(caller, :session_id => caller_session.id, :host => Settings.host, :port => Settings.port, :attempt=>1)) }.response
      5.times do |attempt|
        unless attempt % 5 == 0
          caller_session.pause_for_results(attempt).should == Twilio::Verb.new { |v| v.pause("length" => 30); v.redirect(pause_caller_url(caller, :session_id => caller_session.id, :host => Settings.host, :port => Settings.port, :attempt=>attempt+1)) }.response
        else
          caller_session.pause_for_results(attempt).should == Twilio::Verb.new { |v| v.say("Please enter your call results"); v.pause("length" => 5); v.redirect(pause_caller_url(caller, :session_id => caller_session.id, :host => Settings.host, :port => Settings.port, :attempt => attempt +1)) }.response
        end
      end
    end
  end

  it "returns next question for the caller_session" do
    script = Factory(:script)
    campaign = Factory(:campaign, :script => script)
    voter = Factory(:voter, :campaign => campaign)
    caller_session = Factory(:caller_session, :caller => Factory(:caller), :voter_in_progress => voter, :campaign => campaign)
    Factory(:call_attempt, :caller_session => caller_session, :voter => voter, :campaign => campaign)
    next_question = Factory(:question, :script => script)
    Factory(:question, :script => script)
    caller_session.next_question.should == next_question
  end

  describe "phones-only caller" do

    it "asks caller to choose voter or skip, if caller is phones-only and campaign is preview" do
      campaign = Factory(:campaign, :robo => false, :predictive_type => 'preview')
      caller = Factory(:caller, :is_phones_only => true, :name => "caller name", :pin => "78453", :campaign => campaign)
      voter = Factory(:voter, :campaign => campaign)
      caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign)
      campaign.stub!(:time_period_exceed?).and_return(false)

      caller_session.ask_caller_to_choose_voter.should == Twilio::Verb.new do |v|
        v.gather(:numDigits => 1, :timeout => 10, :action => choose_voter_caller_url(caller, :session => caller_session, :host => Settings.host, :port => Settings.port, :voter => voter), :method => "POST", :finishOnKey => "5") do
          v.say I18n.t(:read_voter_name, :first_name => voter.FirstName, :last_name => voter.LastName)
        end
      end.response
    end

    it "says voter first name and last name, if caller is phones-only and campaign is progressive" do
      campaign = Factory(:campaign, :robo => false, :predictive_type => 'progressive')
      caller = Factory(:caller, :is_phones_only => true, :name => "caller name", :pin => "78453", :campaign => campaign)
      voter = Factory(:voter, :FirstName => "first name", :LastName => "last name", :campaign => campaign)
      caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign)
      campaign.stub!(:time_period_exceed?).and_return(false)
      caller_session.ask_caller_to_choose_voter.should == Twilio::Verb.new do |v|
        v.say "#{voter.FirstName}  #{voter.LastName}."
        v.redirect(phones_only_progressive_caller_url(caller, :session_id => caller_session.id, :voter_id => voter.id, :host => Settings.host, :port => Settings.port), :method => "POST")
      end.response
    end

    it "says 'no more voters to dial', if there are no voters to dial" do
      campaign = Factory(:campaign, :robo => false, :predictive_type => 'progressive')
      caller = Factory(:caller, :is_phones_only => true, :name => "caller name", :pin => "78453", :campaign => campaign)
      campaign.stub!(:time_period_exceed?).and_return(false)
      voter = Factory(:voter, :FirstName => "first name", :LastName => "last name", :campaign => campaign, :status => "Call completed with success.")
      caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign)
      caller_session.ask_caller_to_choose_voter.should == Twilio::Verb.new { |v| v.say I18n.t(:campaign_has_no_more_voters) }.response
    end
  end

  describe "phone responses" do
    let(:script) { Factory(:script) }
    let(:campaign) { Factory(:campaign, :script => script) }
    let(:voter) { Factory(:voter, :campaign => campaign) }
    let(:caller) { Factory(:caller) }
    let(:question) { Factory(:question, :text => "question?", :script => script) }
    let(:caller_session) { Factory(:caller_session, :caller => caller, :voter_in_progress => voter, :campaign => campaign) }

    it "reads questions and possible voter responses to the caller" do
      Factory(:call_attempt, :caller_session => caller_session, :voter => voter, :campaign => campaign)
      Factory(:possible_response, :question => question, :keypad => 1, :value => "response1")
      Factory(:possible_response, :question => question, :keypad => 2, :value => "response2")
      caller_session.next_question.read(caller_session).should == question.read(caller_session)
    end

  end

  describe "reassigned caller to another campaign" do

    it "should be true" do
      caller = Factory(:caller, :campaign => Factory(:campaign))
      caller_session = Factory(:caller_session, :campaign => Factory(:campaign), :caller => caller)
      caller_session.caller_reassigned_to_another_campaign?.should be_true
    end

    it "say the msg 'You have been re-assigned to campaign', if caller is phones_only" do
      caller = Factory(:caller, :campaign => Factory(:campaign), :is_phones_only => true)
      caller_session = Factory(:caller_session, :campaign => Factory(:campaign), :caller => caller)
      caller_session.reassign_caller_session_to_campaign.should == Twilio::Verb.new do |v|
        v.say I18n.t(:re_assign_caller_to_another_campaign, :campaign_name => caller.campaign.name)
        v.redirect(choose_instructions_option_caller_url(caller, :host => Settings.host, :port => Settings.port, :session => caller_session.id, :Digits => "*"))
      end.response
    end

    it "push 'caller_re_assigned_to_campaign' event, if caller is not phones_only" do
      campaign = Factory(:campaign, :use_web_ui => true)
      caller_session = Factory(:caller_session, :campaign => campaign, :caller => Factory(:caller, :campaign => campaign, :is_phones_only => false))
      channel = mock
      Pusher.should_receive(:[]).with(caller_session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("caller_re_assigned_to_campaign", anything)
      caller_session.reassign_caller_session_to_campaign
    end

    it "reassign the caller_session to campaign" do
      campaign1 = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
      campaign2 = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
      caller = Factory(:caller, :campaign => campaign2)
      caller_session = Factory(:caller_session, :caller => caller, :campaign => campaign1, :session_key => "sample", :on_call=> true, :available_for_call => true)
      caller_session.reassign_caller_session_to_campaign
      caller_session.reload.campaign.should == caller.campaign
    end

    it "" do
      campaign1 = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
      campaign2 = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
      phones_only_caller = Factory(:caller, :campaign => campaign2, :is_phones_only => true)
      caller_session = Factory(:caller_session, :caller => phones_only_caller, :campaign => campaign1, :session_key => "sample", :on_call=> true, :available_for_call => true)
      Moderator.should_receive(:publish_event)
      caller_session.start.should == Twilio::Verb.new do |v|
        v.say I18n.t(:re_assign_caller_to_another_campaign, :campaign_name => phones_only_caller.campaign.name)
        v.redirect(choose_instructions_option_caller_url(phones_only_caller, :host => Settings.host, :port => Settings.port, :session => caller_session.id, :Digits => "*"))
      end.response
    end

  end


  describe "pusher" do
    let(:caller) { Factory(:caller) }

    it "publishes information to a caller in session" do
      campaign = Factory(:campaign, :use_web_ui => true)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      event, data = 'event', {}
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with(event, data.merge(:dialer => campaign.predictive_type))
      session.publish(event, data)
    end

    it "does not publish information to a caller not using web ui" do
      campaign = Factory(:campaign, :use_web_ui => false)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      event, data = 'event', 'data'
      Pusher.should_not_receive(:[])
      session.publish(event, data)
    end

    it "pushes voter data being called by a caller" do
      campaign = Factory(:campaign, :use_web_ui => true)
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      voter = Factory(:voter, :campaign => campaign, :caller_session => session)
      voter.stub(:dial_predictive)
      session.should_receive(:publish).with('calling', voter.info)
      session.call(voter)
    end

    # it "pushes voter information when a caller is connected on preview campaign" do
    #   campaign = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
    #   session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
    #   2.times { Factory(:voter, :campaign => campaign) }
    #   channel = mock
    #   Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
    #   channel.should_receive(:trigger).with("caller_connected", anything)
    #   session.start
    # end

    it "should  push  when a caller is connected on a non preview campaign" do
      campaign = Factory(:campaign, :use_web_ui => true, :predictive_type => 'predictive')
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample")
      2.times { Factory(:voter, :campaign => campaign) }
      campaign.stub!(:time_period_exceed?).and_return(false)
      session.stub!(:caller_reassigned_to_another_campaign?).and_return(false)
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("caller_connected_dialer", anything)
      session.start
    end

    it "should push 'caller_disconnected' when the caller session ends" do
      campaign = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample", :on_call=> true, :available_for_call => true)
      2.times { Factory(:voter, :campaign => campaign) }
      Moderator.stub!(:publish_event).with(session.campaign, 'caller_disconnected', {:caller_session_id => session.id, :caller_id => session.caller.id, :campaign_id => campaign.id,
                                                                                     :campaign_active => false, :no_of_callers_logged_in => 0})
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("caller_disconnected", anything)
      session.end
    end

    it "should push 'waiting_for_result' when the caller session is paused" do
      campaign = Factory(:campaign, :use_web_ui => true, :predictive_type => 'preview')
      session = Factory(:caller_session, :caller => caller, :campaign => campaign, :session_key => "sample", :on_call=> true, :available_for_call => true)
      channel = mock
      Pusher.should_receive(:[]).with(session.session_key).and_return(channel)
      channel.should_receive(:trigger).with("waiting_for_result", anything)
      session.pause_for_results
    end

  end


  describe "monitor" do
    it "should join the moderator into conference and update moderator call_sid" do
      moderator = Factory(:moderator, :session => "monitorsession12")
      session = Factory(:caller_session, :moderator => Factory(:moderator, :call_sid => "123"), :session_key => "gjgdfdkg232hl")
      session.join_conference(true, "123new", "monitorsession12").should == Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true) do
          v.conference("gjgdfdkg232hl", :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "#{APP_URL}/callin/hold", :waitMethod =>"GET", :muted => true)
        end
      end.response
      session.moderator.call_sid.should == "123"
    end

    it "should join the moderator into conference and create a moderator with call_sid" do
      moderator = Factory(:moderator, :session => "monitorsession12")
      session = Factory(:caller_session, :session_key => "gjgdfdkg232hl")
      session.join_conference(true, "123", "monitorsession12").should == Twilio::Verb.new do |v|
        v.dial(:hangupOnStar => true) do
          v.conference("gjgdfdkg232hl", :startConferenceOnEnter => false, :endConferenceOnExit => false, :beep => false, :waitUrl => "#{APP_URL}/callin/hold", :waitMethod =>"GET", :muted => true)
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
    CallerSession.time_logged_in(nil,nil,9.minutes.ago, 9.minutes.from_now).should eq("120")
    
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
end
