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
      caller_session.update_attribute('attempt_in_progress', call_attempt)
      script = Factory(:script, :robo => false)
      question1 = Factory(:question, :script => script)
      response1 = Factory(:possible_response, :question => question1)
      question2 = Factory(:question, :script => script)
      response2 = Factory(:possible_response, :question => question2)
      answer = {"0"=>{"name" => "sefrg", "value"=>response1.id}, "1"=>{"name" => "abc", "value"=>response2.id}}

      channel = mock
      Voter.stub_chain(:to_be_dialed, :first).and_return(voter)
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.should_receive(:trigger).with("voter_push", Voter.to_be_dialed.first.info)

      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :answers => answer
      voter.answers.count.should == 2
      caller_session.reload.attempt_in_progress.should be_nil
    end

    it "triggers voter_push Pusher event" do
      channel = mock
      Voter.stub_chain(:to_be_dialed, :first).and_return(voter)
      Pusher.should_receive(:[]).with(anything).and_return(channel)
      channel.should_receive(:trigger).with("voter_push", Voter.to_be_dialed.first.info)
      post :voter_response, :id => call_attempt.id, :voter_id => voter.id, :answers => {}
    end

  end

  describe "calling in" do
    let(:account) { Factory(:account) }
    let(:user) { Factory(:user, :account => account) }
    let(:campaign) { Factory(:campaign, :account => account, :robo => false) }
    let(:voter) { Factory(:voter) }
    let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign) }

    it "connects the voter to an available caller" do
      Factory(:caller_session, :campaign => campaign, :available_for_call => false)
      available_caller = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller))
      post :connect, :id => call_attempt.id

      call_attempt.reload.caller.should == available_caller.caller
      available_caller.reload.voter_in_progress.should == voter
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'true', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host) do |d|
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
        r.Dial :hangupOnStar => 'true', :action => disconnect_call_attempt_path(call_attempt, :host => Settings.host) do |d|
          d.Conference available_caller.session_key, :wait_url => hold_call_url(:host => Settings.host), :waitMethod => 'GET', :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
    end

    it "hangs up if there are no callers on call" do
      available_caller = Factory(:caller_session, :campaign => campaign, :available_for_call => false, :on_call => false)
      post :connect, :id => call_attempt.id
      response.body.should == Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

    it "plays a voice mail to a voters answering the campaign uses recordings" do
      campaign = Factory(:campaign, :use_recordings => true, :recording => Factory(:recording, :file_file_name => 'abc.mp3', :account => Factory(:account)))
      call_attempt = Factory(:call_attempt, :voter => voter, :campaign => campaign)
      post :connect, :id => call_attempt.id, :DialCallStatus => "answered-machine"
      call_attempt.reload.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.voter.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.call_end.should_not be_nil
    end

    it "hangs up on the voters answering machine when the campaign does not use recordings" do
      post :end, :id => call_attempt.id, :DialCallStatus => "hangup-machine"

      response.body.should == Twilio::TwiML::Response.new { |r| r.Hangup }.text
      call_attempt.reload.status.should == CallAttempt::Status::HANGUP
      call_attempt.voter.status.should == CallAttempt::Status::HANGUP
      call_attempt.call_end.should_not be_nil
      call_attempt.voter.call_back.should == true
    end

    it "updates the details of a call not answered" do
      post :end, :id => call_attempt.id, :DialCallStatus => "no-answer"
      call_attempt.reload.status.should == CallAttempt::Status::NOANSWER
      call_attempt.voter.status.should == CallAttempt::Status::NOANSWER
      voter.reload.call_back.should be_true
      call_attempt.call_end.should_not be_nil
    end

    it "updates the details of a busy voter" do
      post :end, :id => call_attempt.id, :DialCallStatus => "busy"
      call_attempt.reload.status.should == CallAttempt::Status::BUSY
      call_attempt.voter.status.should == CallAttempt::Status::BUSY
      voter.reload.call_back.should be_true
      call_attempt.call_end.should_not be_nil
    end

    it "puts the caller back on hold when a voter is disconnected" do
      call_attempt.update_attributes(:caller_session => Factory(:caller_session))
      post :disconnect, :id => call_attempt.id
      response.body.should == call_attempt.disconnect
    end

    it "updates the details of a call failed" do
      post :end, :id => call_attempt.id, :DialCallStatus => "fail"
      call_attempt.reload.status.should == CallAttempt::Status::FAILED
      call_attempt.voter.status.should == CallAttempt::Status::FAILED
      voter.reload.call_back.should be_true
      call_attempt.call_end.should_not be_nil
    end

    it "notifies pusher when a call attempt is connected" do
      session_key = 'foo'
      custom_field = Factory(:custom_voter_field)
      Factory(:custom_voter_field_value, :voter => voter, :custom_voter_field => custom_field, :value => 'value')
      session = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true, :caller => Factory(:caller), :session_key => session_key)
      pusher_session = mock
      pusher_session.should_receive(:trigger).with('voter_connected', {:attempt_id=> call_attempt.id, :voter => voter.info})
      Pusher.stub(:[]).with(session_key).and_return(pusher_session)
      post :connect, :id => call_attempt.id
    end

    it "notifies "

  end
end
