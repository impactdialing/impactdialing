require "spec_helper"

describe CallAttemptsController do
  it "updates a call attempt" do
    call_attempt = Factory(:call_attempt, :scheduled_date => nil)
    scheduled_date = 2.days.from_now
    put :update, :id => call_attempt.id, :call_attempt => {:scheduled_date => scheduled_date}
    call_attempt.reload.scheduled_date.to_s.should == scheduled_date.to_s
    call_attempt.status.should == CallAttempt::Status::SCHEDULED
    response.should be_ok
  end

  describe "gathering responses" do
    let(:account) { Factory(:account) }
    let(:user) { Factory(:user, :account => account) }
    let(:campaign) { Factory(:campaign, :account => account, :robo => false, :use_web_ui => true) }
    let(:voter) { Factory(:voter) }
    let(:caller_session){ Factory(:caller_session) }
    let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => caller_session) }

    it "collects voter responses" do
      script = Factory(:script, :robo => false)
      question1 = Factory(:question, :script => script)
      response1 = Factory(:possible_response, :question => question1)
      question2 = Factory(:question, :script => script)
      response2 = Factory(:possible_response, :question => question2)
      answer = {"0"=>{"name" => "sefrg", "value"=>response1.id}, "1"=>{"name" => "abc", "value"=>response2.id}}

      channel = mock
      Voter.stub_chain(:to_be_dialed, :first).and_return(voter)
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.should_receive(:trigger).with("voter_push", Voter.to_be_dialed.first.info.merge(:dialer => campaign.predictive_type))

      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :answers => answer
      voter.answers.count.should == 2
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

  end

  describe "calling in" do
    let(:account) { Factory(:account) }
    let(:user) { Factory(:user, :account => account) }
    let(:campaign) { Factory(:campaign, :account => account, :robo => false) }
    let(:voter) { Factory(:voter, :campaign => campaign, :call_back => false) }
    let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign, :caller_session => Factory(:caller_session)) }

    it "connects the voter to an available caller" do
      Factory(:caller_session, :campaign => campaign, :available_for_call => false)
      available_caller = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      post :connect, :id => call_attempt.id

      call_attempt.reload.caller.should == available_caller.caller
      available_caller.reload.voter_in_progress.should == voter
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host) do |d|
          d.Conference available_caller.session_key, :wait_url => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
    end

    it "connects a voter to a specified caller" do
      Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => false)
      available_caller = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => false)
      voter.update_attribute(:caller_session, available_caller)
      post :connect, :id => call_attempt.id
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host) do |d|
          d.Conference available_caller.session_key, :wait_url => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
    end

    it "disconnects a call_attempt from a conference" do
      call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::INPROGRESS, :caller_session => Factory(:caller_session), :voter => Factory(:voter))
      channel = mock
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.stub(:trigger)
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
      available_caller = Factory(:caller_session, :campaign => campaign, :available_for_call => false, :on_call => false)
      post :connect, :id => call_attempt.id
      response.body.should == Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

    it "plays a voice mail to a voters answering the campaign uses recordings" do
      campaign = Factory(:campaign, :use_recordings => true, :recording => Factory(:recording, :file_file_name => 'abc.mp3', :account => Factory(:account)))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      post :connect, :id => call_attempt.id, :CallStatus => "answered-machine"
      call_attempt.reload.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.voter.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.call_end.should_not be_nil
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
      voter.reload.call_back.should be_true
      call_attempt.call_end.should_not be_nil
    end

    it "updates the details of a busy voter" do
      post :end, :id => call_attempt.id, :CallStatus => "busy"
      call_attempt.reload.status.should == CallAttempt::Status::BUSY
      call_attempt.voter.status.should == CallAttempt::Status::BUSY
      voter.reload.call_back.should be_true
      call_attempt.call_end.should_not be_nil
    end

    it "updates the details of a call failed" do
      post :end, :id => call_attempt.id, :CallStatus => "failed"
      call_attempt.reload.status.should == CallAttempt::Status::FAILED
      call_attempt.voter.status.should == CallAttempt::Status::FAILED
      voter.reload.call_back.should be_true
      call_attempt.call_end.should_not be_nil
    end

    it "notifies pusher when a call attempt is connected" do
      session_key = 'foo'
      custom_field = Factory(:custom_voter_field)
      Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => 'value')
      Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller), :session_key => session_key, :voter_in_progress => voter)
      pusher_session = mock
      pusher_session.should_receive(:trigger).with('voter_connected', {:attempt_id=> call_attempt.id, :voter => voter.info}.merge(:dialer => campaign.predictive_type))
      Pusher.stub(:[]).with(session_key).and_return(pusher_session)
      post :connect, :id => call_attempt.id
    end

    it "notifies a pusher event if call attempt is disconnected" do

    end

  end
end
