require "spec_helper"

describe CallAttemptsController do
  it "updates a call attempt" do
    call_attempt = Factory(:call_attempt, :scheduled_date => nil)
    scheduled_date = 2.days.from_now
    put :update, :id => call_attempt.id, :call_attempt => {:scheduled_date => scheduled_date}
    call_attempt.reload.scheduled_date.to_s.should == scheduled_date.to_s
    call_attempt.status.should == CallAttempt::Status::SCHEDULED
    response.status.should == '200 OK'
  end

  describe "calling in" do
    let(:user) { Factory(:user) }
    let(:campaign) { Factory(:campaign, :user => user, :robo => false) }
    let(:voter) { Factory(:voter) }
    let(:call_attempt) { Factory(:call_attempt, :voter => voter, :campaign => campaign) }

    it "connects the voter to an available caller" do
      Factory(:caller_session, :campaign => campaign, :available_for_call => false)
      available_caller = Factory(:caller_session, :campaign => campaign, :available_for_call => true, :on_call => true)
      post :connect, :id => call_attempt.id

      available_caller.reload.voter_in_progress.should == voter
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Dial :hangupOnStar => 'false' do |d|
          d.Conference "session#{available_caller.id}", :wait_url => "", :beep => false, :endConferenceOnExit => true, :maxParticipants => 2
        end
      end.text
    end

    it "waits if there are on call callers but not available for call" do
      available_caller = Factory(:caller_session, :campaign => campaign, :available_for_call => false, :on_call => true)
      post :connect, :id => call_attempt.id
      response.body.should == Twilio::TwiML::Response.new do |r|
        r.Pause :length => 2
        r.Redirect "#{connect_call_attempts_path(:id => call_attempt.id)}"
      end.text
    end

    it "hangs up if there are no callers on call" do
      available_caller = Factory(:caller_session, :campaign => campaign, :available_for_call => false, :on_call => false)
      post :connect, :id => call_attempt.id
      response.body.should == Twilio::TwiML::Response.new { |r| r.Hangup }.text
    end

    it "records a voter on voicemail" do
      post :connect, :id => call_attempt.id, :DialStatus => "answered-machine"
      call_attempt.reload.status.should == CallAttempt::Status::VOICEMAIL
      call_attempt.voter.status.should == CallAttempt::Status::VOICEMAIL
    end

    it "updates the details of a call not answered" do
      post :connect, :id => call_attempt.id, :DialStatus => "no-answer"
      call_attempt.reload.status.should == CallAttempt::Status::NOANSWER
      call_attempt.voter.status.should == CallAttempt::Status::NOANSWER
    end


  end
end
