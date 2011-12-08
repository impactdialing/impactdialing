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
      channel.should_receive(:trigger).with("voter_push", voter2.info.merge(:dialer => campaign.predictive_type))

      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :question => {question1.id=> response1.id, question2.id=>response2.id}
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
      channel.should_receive(:trigger).with("voter_push", voter2.info.merge(:dialer => campaign.predictive_type))

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
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.should_receive(:trigger).with("voter_push", campaign.all_voters.to_be_dialed.first.info.merge({dialer: next_voter.campaign.predictive_type}))
      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :answers => {}
    end

    describe "phones only" do
      let(:account) { Factory(:account) }
      let(:user) { Factory(:user, :account => account) }
      let(:script) { Factory(:script) }
      let(:campaign) { Factory(:campaign, :account => account, :robo => false, :use_web_ui => true, :script => script) }
      let(:voter) { Factory(:voter, :campaign => campaign) }
      let(:caller_session) { Factory(:caller_session, :campaign => campaign, :session_key => "some_key") }
      let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => caller_session) }
      let(:first_question){ Factory(:question, :script => script) }

      it "gathers responses" do
        Factory(:possible_response, :keypad => 1, :question => first_question, :value => "value")
        post :gather_response, :id => call_attempt.id, :question_id => first_question.id, :Digits => "1"
        voter.answers.size.should == 1
      end

      it "reads out the next question" do
        Factory(:possible_response, :keypad => 1, :question => first_question, :value => "value")
        next_question = Factory(:question, :script => script)
        Factory(:possible_response, :question => next_question,:keypad => "1", :value => "value")
        post :gather_response, :id => call_attempt.id, :question_id => first_question.id, :Digits => "1"
        response.body.should == next_question.read(call_attempt)
      end

      it "places the voter in a conference when all questions are answered" do
        Factory(:possible_response, :keypad => 1, :question => first_question, :value => "value")
        post :gather_response, :id => call_attempt.id, :question_id => first_question.id, :Digits => "1"
        response.body.should == call_attempt.caller_session.start
      end


    end

  end

  describe "calling in" do
    let(:account) { Factory(:account) }
    let(:user) { Factory(:user, :account => account) }
    let(:campaign) { Factory(:campaign, :account => account, :robo => false) }
    let(:voter) { Factory(:voter, :campaign => campaign, :call_back => false) }
    let(:caller_session) { caller_session = Factory(:caller_session, :session_key => "sample")}
    let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => caller_session) }

    it "connects the voter to an available caller" do
      Factory(:caller_session, :campaign => campaign, :available_for_call => false)
      available_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      call_attempt.update_attributes(caller_session: available_session)
      Moderator.stub!(:publish_event).with(available_session.campaign, 'voter_connected', {:campaign_id => available_session.campaign.id,
        :caller_id => call_attempt.caller_session.caller.id, :dials_in_progress => 1})
      post :connect, :id => call_attempt.id

      call_attempt.reload.caller.should == available_session.caller
      available_session.reload.voter_in_progress.should == voter
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host), :record=>call_attempt.campaign.account.record_calls do |d|
          d.Conference available_session.session_key, :wait_url => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
    end

    it "connects a voter to a specified caller" do
      Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => false)
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => false)
      call_attempt.voter.update_attribute(:caller_session, caller_session)
      Moderator.stub!(:publish_event).with(caller_session.campaign, 'voter_connected', {:campaign_id => caller_session.campaign.id,
        :caller_id => caller_session.caller.id, :dials_in_progress => 1})
      post :connect, :id => call_attempt.id
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host), :record=>call_attempt.campaign.account.record_calls do |d|
          d.Conference caller_session.session_key, :wait_url => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
    end

    it "disconnects a call_attempt from a conference" do
      caller = Factory(:caller)
      campaign = Factory(:campaign)
      caller_session = Factory(:caller_session, :caller =>caller, :campaign => campaign)
      call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::INPROGRESS, :caller_session => caller_session, :voter => Factory(:voter))
      channel = mock

      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.stub(:trigger)
      Moderator.stub!(:publish_event).with(call_attempt.campaign, 'voter_disconnected', {:campaign_id => call_attempt.campaign.id, :caller_id => call_attempt.caller_session.caller.id,:dials_in_progress => 0, :voters_remaining => 0})
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
      CallAttempt.stub(:find).and_return(call_attempt)
      post :connect, :id => call_attempt.id, :AnsweredBy => 'machine'
      response.body.should == call_attempt.hangup
      call_attempt.reload.voter.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.status.should == CallAttempt::Status::VOICEMAIL
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

    it "notifies pusher when a call attempt is connected" do
      session_key = 'foo'
      custom_field = Factory(:custom_voter_field)
      Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => 'value')
      caller_session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller), :session_key => session_key, :voter_in_progress => voter)
      call_attempt.update_attributes(caller_session: caller_session)
      pusher_session = mock
      voter.status = CallAttempt::Status::INPROGRESS
      pusher_session.should_receive(:trigger).with('voter_connected', {:attempt_id=> call_attempt.id, :voter => voter.info}.merge(:dialer => campaign.predictive_type))
      Pusher.stub(:[]).with(session_key).and_return(pusher_session)
      Moderator.stub!(:publish_event).with(caller_session.campaign, 'voter_connected', {:campaign_id => caller_session.campaign.id,:caller_id => call_attempt.caller_session.caller.id, :dials_in_progress => 1})
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
      Pusher.stub(:[]).with(session_key).and_return(pusher_session)
      pusher_session.should_receive(:trigger).with("answered_by_machine", {:dialer=>"preview"})
      pusher_session.should_receive(:trigger).with('voter_push', next_voter.info.merge(:dialer => campaign.predictive_type))
      post :connect, :id => call_attempt.id, :AnsweredBy => "machine"
    end
    
    it "if the call attempt is ABANDONED, it doesn't modify status, when call end" do
      voter = Factory(:voter, :status => CallAttempt::Status::ABANDONED)
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => Factory(:caller_session), :status => CallAttempt::Status::ABANDONED)
      post :end, :id => call_attempt.id, :CallStatus => "completed"
      call_attempt.reload.status.should == CallAttempt::Status::ABANDONED
      call_attempt.voter.reload.status.should == CallAttempt::Status::ABANDONED
    end
  end
end
