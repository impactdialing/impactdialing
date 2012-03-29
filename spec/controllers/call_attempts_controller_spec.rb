require "spec_helper"

describe CallAttemptsController do

  describe "gathering responses" do
    let(:account) { Factory(:account) }
    let(:user) { Factory(:user, :account => account) }
    let(:campaign) { Factory(:campaign, :account => account, :robo => false, :use_web_ui => true) }
    let(:voter) { Factory(:voter, :campaign => campaign) }
    let(:caller_session) { Factory(:caller_session) }
    let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => caller_session) }

    it "collects voter responses" do
      script = Factory(:script, :robo => false)
      voter2 = Factory(:voter, :campaign => campaign)
      question1 = Factory(:question, :script => script)
      response1 = Factory(:possible_response, :question => question1)
      question2 = Factory(:question, :script => script)
      response2 = Factory(:possible_response, :question => question2)

      channel = mock
      # Voter.stub_chain(:to_be_dialed, :first).and_return(voter)
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      info = voter2.info
      info[:fields]['status'] = CallAttempt::Status::READY
      channel.should_receive(:trigger).with("voter_push", info.merge(:dialer => campaign.predictive_type))

      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :question => {question1.id=> response1.id, question2.id=>response2.id}
      voter.answers.count.should == 2
    end
    
    it "collects voter responses if voter id is blank from call attempt" do
      script = Factory(:script, :robo => false)
      voter2 = Factory(:voter, :campaign => campaign)
      question1 = Factory(:question, :script => script)
      response1 = Factory(:possible_response, :question => question1)
      question2 = Factory(:question, :script => script)
      response2 = Factory(:possible_response, :question => question2)

      channel = mock
      # Voter.stub_chain(:to_be_dialed, :first).and_return(voter)
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      info = voter2.info
      info[:fields]['status'] = CallAttempt::Status::READY
      channel.should_receive(:trigger).with("voter_push", info.merge(:dialer => campaign.predictive_type))

      post :voter_response, :id => call_attempt.id, :voter_id => "", :question => {question1.id=> response1.id, question2.id=>response2.id}
      voter.answers.count.should == 2
    end
    

    it "retry responses should dial voter again later" do
      voter2 = Factory(:voter, campaign: campaign)
      script = Factory(:script, :robo => false)
      question1 = Factory(:question, :script => script)
      response1 = Factory(:possible_response, :question => question1)
      question2 = Factory(:question, :script => script)
      response2 = Factory(:possible_response, :question => question2, :retry => true)

      channel = mock
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      info = voter2.info
      info[:fields]['status'] = CallAttempt::Status::READY

      channel.should_receive(:trigger).with("voter_push", info.merge(:dialer => campaign.predictive_type))

      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :question => {question1.id=> response1.id, question2.id=>response2.id}
      voter.answers.count.should == 2
      voter.reload.status.should ==Voter::Status::RETRY
    end

    it "sends next voter to be dialed via voter_push Pusher event" do
      Factory(:voter, :campaign => Factory(:campaign), :status => Voter::Status::NOTCALLED)
      voter = Factory(:voter, :campaign => campaign, :status => CallAttempt::Status::SUCCESS, :call_back => false)
      next_voter = Factory(:voter, :campaign => campaign, :status => Voter::Status::NOTCALLED, :call_back => false)
      campaign.all_voters.size.should == 2
      channel = mock
      info = campaign.all_voters.to_be_dialed.first.info
      info[:fields]['status'] = CallAttempt::Status::READY

      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.should_receive(:trigger).with("voter_push", info.merge({dialer: next_voter.campaign.predictive_type}))
      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :answers => {}
    end
    
    it "not send send next voter to be dialed via voter_push Pusher event when stop calling" do
      Factory(:voter, :campaign => Factory(:campaign), :status => Voter::Status::NOTCALLED)
      voter = Factory(:voter, :campaign => campaign, :status => CallAttempt::Status::SUCCESS, :call_back => false)
      next_voter = Factory(:voter, :campaign => campaign, :status => Voter::Status::NOTCALLED, :call_back => false)
      campaign.all_voters.size.should == 2
      channel = mock
      info = campaign.all_voters.to_be_dialed.first.info
      info[:fields]['status'] = CallAttempt::Status::READY

      Pusher.should_not_receive(:[]).with(anything).and_return(channel)
      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :answers => {}, stop_calling: true
    end
    
  end

  describe "phones only" do
    let(:account) { Factory(:account) }
    let(:user) { Factory(:user, :account => account) }
    let(:campaign) { Factory(:campaign, :account => account, :robo => false, :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00")) }
    let(:caller) { Factory(:caller) }

    it "routes different calls to callers sharing credentials" do
      session1 = Factory(:caller_session, :session_key => "sample1", :campaign => campaign, :available_for_call => true, :on_call => true)
      session2 = Factory(:caller_session, :session_key => "sample2", :campaign => campaign, :available_for_call => true, :on_call => true)
      attempt1 = Factory(:call_attempt, :voter => Factory(:voter,:campaign => campaign), :campaign => campaign)
      attempt2 = Factory(:call_attempt, :voter => Factory(:voter,:campaign => campaign), :campaign => campaign)
      post :connect, :id => attempt1.id, :AnsweredBy => "human"
      post :connect, :id => attempt2.id, :AnsweredBy => "human"
      session1.voter_in_progress.should_not be_nil
      session2.voter_in_progress.should_not be_nil
      session1.attempt_in_progress.should_not == session2.attempt_in_progress
    end
  end

  describe "calling in" do
    let(:account) { Factory(:account) }
    let(:user) { Factory(:user, :account => account) }
    let(:campaign) { Factory(:campaign, :account => account, :robo => false, :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00")) }
    let(:caller) { Factory(:caller, :account => account, :campaign => campaign)}
    let(:voter) { Factory(:voter, :campaign => campaign, :call_back => false) }
    let(:caller_session) { caller_session = Factory(:caller_session, :session_key => "sample", :caller => caller, :campaign => campaign) }
    let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => caller_session) }

    it "connects the voter to an available caller" do
      Factory(:caller_session, :campaign => campaign, :available_for_call => false)
      available_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      call_attempt.update_attributes(caller_session: available_session)
      Moderator.stub!(:publish_event).with(available_session.campaign, 'voter_connected', {:caller_session_id => call_attempt.caller_session.id,:campaign_id => available_session.campaign.id,
                                                                                           :caller_id => call_attempt.caller_session.caller.id})
      post :connect, :id => call_attempt.id

      call_attempt.reload.caller.should == available_session.caller
      available_session.reload.voter_in_progress.should == voter
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host), :record=>call_attempt.campaign.account.record_calls do |d|
          d.Conference available_session.session_key, :waitUrl => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
    end

    it "updates connect time" do
      now = Time.now
      Time.stub(:now).and_return(now)
      post :connect, :id => call_attempt.id
      Time.parse(call_attempt.reload.connecttime.to_s).to_s.should == now.utc.to_s
    end

    it "connects a voter to a specified caller" do
      Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => false)
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => false)
      call_attempt.voter.update_attribute(:caller_session, caller_session)
      Moderator.stub!(:publish_event).with(caller_session.campaign, 'voter_connected', {:caller_session_id => caller_session.id, :campaign_id => caller_session.campaign.id,
                                                                                        :caller_id => caller_session.caller.id})
      post :connect, :id => call_attempt.id
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host), :record=>call_attempt.campaign.account.record_calls do |d|
          d.Conference caller_session.session_key, :waitUrl => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
    end

    it "disconnects a call_attempt from a conference" do
      caller = Factory(:caller)
      campaign = Factory(:campaign)
      caller_session = Factory(:caller_session, :caller =>caller, :campaign => campaign)
      call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::INPROGRESS, :caller_session => caller_session, :voter => Factory(:voter, :campaign => campaign))
      channel = mock

      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.stub(:trigger)
      Moderator.stub!(:publish_event).with(call_attempt.campaign, 'voter_disconnected', {:caller_session_id => caller_session.id, :campaign_id => call_attempt.campaign.id, :caller_id => call_attempt.caller_session.caller.id, :voters_remaining => 0})
      post :disconnect, :id => call_attempt.id
      response.body.should == call_attempt.hangup
      call_attempt.reload.status.should == CallAttempt::Status::SUCCESS
    end

    it "hangs up given a call_attempts call sid" do
      pending
      call_attempt = Factory(:call_attempt, :sid => "some_sid")
      CallAttempt.should_receive(:find).and_return(call_attempt)
      #call_attempt.stub(:end_running_call).and_return(mock)
      call_attempt.should_receive(:end_running_call)
      post :hangup, :id => call_attempt.id
    end

    it "hangs up if there are no callers on call" do
      available_caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => false, :on_call => false)
      call_attempt.update_attributes(caller_session: available_caller_session)
      post :connect, :id => call_attempt.id
      response.body.should == Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

    it "hangs up when a answering machine is detected and campaign uses no recordings" do
      voter2 = Factory(:voter, :campaign => campaign, :call_back => false)
      CallAttempt.stub(:find).and_return(call_attempt)
      post :connect, :id => call_attempt.id, :AnsweredBy => 'machine'
      response.body.should == call_attempt.hangup
      call_attempt.reload.voter.status.should == CallAttempt::Status::HANGUP
      call_attempt.status.should == CallAttempt::Status::HANGUP
    end

    it "plays a voice mail to a voters answering the campaign uses recordings" do
      campaign = Factory(:campaign, :use_recordings => true, :answering_machine_detect => true, :recording => Factory(:recording, :file_file_name => 'abc.mp3', :account => Factory(:account)))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => Factory(:caller_session))
      post :connect, :id => call_attempt.id, :AnsweredBy => "machine"
      call_attempt.reload.voter.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.status.should == CallAttempt::Status::VOICEMAIL
      response.body.should == call_attempt.play_recorded_message
    end

    #it "hangs up on the voters answering machine when the campaign does not use recordings" do
    #  post :end, :id => call_attempt.id, :CallStatus => "hangup-machine"
    #
    #  response.body.should == Twilio::TwiML::Response.new { |r| r.Hangup }.text
    #  call_attempt.reload.status.should == CallAttempt::Status::HANGUP
    #  call_attempt.voter.status.should == CallAttempt::Status::HANGUP
    #  call_attempt.call_end.should_not be_nil
    #  call_attempt.voter.call_back.should == true
    #end

    it "updates the details of a call not answered" do
      campaign.stub(:time_period_exceed?).and_return(false)
      post :end, :id => call_attempt.id, :CallStatus => "no-answer"
      call_attempt.reload.status.should == CallAttempt::Status::NOANSWER
      call_attempt.voter.status.should == CallAttempt::Status::NOANSWER
    end

    it "updates the details of a busy voter" do
      post :end, :id => call_attempt.id, :CallStatus => "busy"
      call_attempt.reload.status.should == CallAttempt::Status::BUSY
      call_attempt.voter.status.should == CallAttempt::Status::BUSY
    end

    it "updates the details of a call failed" do
      post :end, :id => call_attempt.id, :CallStatus => "failed"
      call_attempt.reload.status.should == CallAttempt::Status::FAILED
      call_attempt.voter.status.should == CallAttempt::Status::FAILED
    end
    
    it "not updates the details of a call status, if it is abandoned" do
      call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::ABANDONED, :voter => Factory(:voter, :status => CallAttempt::Status::ABANDONED))
      post :end, :id => call_attempt.id, :CallStatus => "anything"
      call_attempt.reload.status.should == CallAttempt::Status::ABANDONED
      call_attempt.voter.status.should == CallAttempt::Status::ABANDONED
    end
    
    it "not updates the details of a call status, if it is answering machine detected" do
      call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::HANGUP, :voter => Factory(:voter, :status => CallAttempt::Status::HANGUP))
      post :end, :id => call_attempt.id, :CallStatus => "anything"
      call_attempt.reload.status.should == CallAttempt::Status::HANGUP
      call_attempt.voter.status.should == CallAttempt::Status::HANGUP
    end
    
    it "not updates the details of a call status, if it is voice mailed" do
      call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::VOICEMAIL, :voter => Factory(:voter, :status => CallAttempt::Status::VOICEMAIL))
      post :end, :id => call_attempt.id, :CallStatus => "anything"
      call_attempt.reload.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.voter.status.should == CallAttempt::Status::VOICEMAIL
    end
    
    it "notifies pusher when a call attempt is connected" do
      session_key = 'foo'
      custom_field = Factory(:custom_voter_field)
      Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => 'value')
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller), :session_key => session_key)
      voter.update_attributes(:status => CallAttempt::Status::INPROGRESS, :caller_session => caller_session, caller_id: caller_session.caller_id)
      call_attempt.update_attributes(caller_session: caller_session)
      pusher_session = mock
      pusher_session.should_receive(:trigger).with('voter_connected', {:attempt_id=> call_attempt.id, :voter => voter.info}.merge(:dialer => campaign.predictive_type))
      Pusher.stub(:[]).with(session_key).and_return(pusher_session)
      Moderator.stub!(:publish_event).with(caller_session.campaign, 'voter_connected', {:caller_session_id => caller_session.id, :campaign_id => caller_session.campaign.id, :caller_id => call_attempt.caller_session.caller.id})
      post :connect, :id => call_attempt.id
    end

    it "notifies pusher when a call attempt is answered by a machine." do
      session_key = 'foo'
      campaign.recording = Factory(:recording)
      campaign.save
      voter = Factory(:voter, :last_call_attempt_time => Time.now)
      session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller), :session_key => session_key, :voter_in_progress => voter)
      call_attempt = Factory(:call_attempt, :caller_session => session, :voter => voter, :campaign => campaign)
      next_voter = Factory(:voter, :campaign => campaign, :status => Voter::Status::NOTCALLED)
      pusher_session = mock

      info = next_voter.info
      info[:fields]['status'] = CallAttempt::Status::READY
      Pusher.stub(:[]).with(session_key).and_return(pusher_session)
      pusher_session.should_receive(:trigger).with("answered_by_machine", {:dialer=>"preview"})
      pusher_session.should_receive(:trigger).with('voter_push', info.merge(:dialer => campaign.predictive_type))
      pusher_session.should_receive(:trigger).with('conference_started', {:dialer=>"preview"})
      post :connect, :id => call_attempt.id, :AnsweredBy => "machine"
      call_attempt.reload.wrapup_time.should_not be_nil
    end

    it "if the call attempt is ABANDONED, it doesn't modify status, when call end" do
      voter = Factory(:voter, :status => CallAttempt::Status::ABANDONED)
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => Factory(:caller_session), :status => CallAttempt::Status::ABANDONED)
      post :end, :id => call_attempt.id, :CallStatus => "completed"
      call_attempt.reload.status.should == CallAttempt::Status::ABANDONED
      call_attempt.voter.reload.status.should == CallAttempt::Status::ABANDONED
    end

    it "if the call attempt is ABANDONED, it  modifies end_tme, when call end" do
      time_now = Time.now
      Time.stub(:now).and_return(time_now)
      voter = Factory(:voter, :status => CallAttempt::Status::ABANDONED)
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => Factory(:caller_session), :status => CallAttempt::Status::ABANDONED)
      post :end, :id => call_attempt.id, :CallStatus => "completed"
      call_attempt.reload.call_end.utc.to_i.should == time_now.utc.to_i
      call_attempt.voter.reload.last_call_attempt_time.utc.to_i.should == time_now.utc.to_i
    end

  end
end
