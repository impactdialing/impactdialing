require "spec_helper"

describe TwilioController do
  let(:recording) { Factory(:robo_recording, :file_file_name => 'foo.wav') }
  let(:campaign) { Factory(:robo, :script => Factory(:script, :robo_recordings => [recording])) }
  let(:call_attempt) { Factory(:call_attempt, :campaign => campaign, :voter => Factory(:voter)) }

  it "proceeds with the call if the call was answered" do
    post :callback, :call_attempt_id => call_attempt.id, :CallStatus => 'in-progress'
    response.body.should == recording.twilio_xml(call_attempt)
    call_attempt.reload.status.should == CallAttempt::Status::MAP['in-progress']
  end

  ['queued', 'busy', 'failed', 'no-answer', 'canceled',].each do |call_status|
    it "hangs up if the call has a status of #{call_status}" do
      post :callback, :call_attempt_id => call_attempt.id, :CallStatus => call_status
      call_attempt.voter.reload.status.should == CallAttempt::Status::MAP[call_status]
      response.body.should == Twilio::Verb.hangup
      call_attempt.reload.status.should == CallAttempt::Status::MAP[call_status]
    end

    ['report_error', 'call_ended'].each do |callback|
      it "#{callback} updates the call attempt status on #{call_status}" do
        post callback, :call_attempt_id => call_attempt.id, :CallStatus => call_status
        call_attempt.reload.status.should == CallAttempt::Status::MAP[call_status]
      end
    end
  end

  it "hangs up a call that has reported an error" do
    post :report_error, :call_attempt_id => call_attempt.id, :CallStatus => CallAttempt::Status::INPROGRESS
    response.body.should == Twilio::Verb.hangup
  end

  it "leaves a voicemail when the call is answered by machine" do
    campaign.update_attribute(:voicemail_script , Factory(:script, :robo => true, :for_voicemail => true, :robo_recordings => [recording]))
    RedisCallAttempt.should_receive(:set_status).with(call_attempt.id, CallAttempt::Status::VOICEMAIL)
    RedisVoter.should_receive(:set_status).with(call_attempt.voter.id, CallAttempt::Status::VOICEMAIL)    
    post :callback, :call_attempt_id => call_attempt.id, :AnsweredBy => 'machine', :CallStatus => 'in-progress'
  end

  it "doesn't updates voter status, if it is answered by machine" do
    voter = Factory(:voter, :status => CallAttempt::Status::HANGUP, :campaign => campaign)
    call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::HANGUP, :campaign => campaign, :voter => voter)
    voter.update_attributes(:last_call_attempt => call_attempt)
    post :call_ended, :call_attempt_id => call_attempt.id, :CallStatus => "completed"
    call_attempt.reload.status.should == CallAttempt::Status::HANGUP
    call_attempt.voter.status.should == CallAttempt::Status::HANGUP
  end

  it "doesn't updates voter status, if the voice mail delivered" do
    voter = Factory(:voter, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign)
    call_attempt = Factory(:call_attempt, :status => CallAttempt::Status::VOICEMAIL, :campaign => campaign, :voter => voter)
    voter.update_attributes(:last_call_attempt => call_attempt)
    post :call_ended, :call_attempt_id => call_attempt.id, :CallStatus => "completed"
    call_attempt.reload.status.should == CallAttempt::Status::VOICEMAIL
    call_attempt.voter.status.should == CallAttempt::Status::VOICEMAIL
  end

end
