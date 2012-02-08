require "spec_helper"

describe TransferController do
  
  it "should dial a number" do
    script =  Factory(:script)
    campaign = Factory(:campaign, script: script)
    transfer = Factory(:transfer, script: script, phone_number: "1234567890")
    caller_session = Factory(:caller_session)
    call_attempt = Factory(:call_attempt)
    voter = Factory(:voter, Phone: "1234567890")
    Transfer.should_receive(:find).and_return(transfer)
    transfer.should_receive(:dial).with(caller_session, call_attempt, voter, Transfer::Type::WARM)
    post :dial, transfer: {id: transfer.id, type: Transfer::Type::WARM} , caller_session:  caller_session.id, call_attempt: call_attempt.id, voter: voter.id
  end
  
  it "should disconnect and set attempt status as success" do
    transfer_attempt = Factory(:transfer_attempt)
    post :disconnect, id: transfer_attempt.id
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq(CallAttempt::Status::SUCCESS)    
  end
  
  it "should connect a call to a conference" do
    campaign =  Factory(:campaign)
    caller_session = Factory(:caller_session, campaign: campaign)
    call_attempt = Factory(:call_attempt)
    transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
    post :connect, id: transfer_attempt.id
    transfer_attempt.reload
    transfer_attempt.connecttime.should_not be_nil
  end
  
  it "should end a successful call" do
    campaign =  Factory(:campaign)
    caller_session = Factory(:caller_session, campaign: campaign)
    transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'completed'
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq('Call completed with success.')
    transfer_attempt.call_end.should_not be_nil    
  end
  
  it "should end a no-answer call" do
    campaign =  Factory(:campaign)
    caller_session = Factory(:caller_session, campaign: campaign)
    transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'no-answer'
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq('No answer')
    transfer_attempt.call_end.should_not be_nil    
  end
  
  it "should end a busy call" do
    campaign =  Factory(:campaign)
    caller_session = Factory(:caller_session, campaign: campaign)
    transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'busy'
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq('No answer busy signal')
    transfer_attempt.call_end.should_not be_nil    
  end
  
  it "should end a failed call" do
    campaign =  Factory(:campaign)
    caller_session = Factory(:caller_session, campaign: campaign)
    transfer_attempt = Factory(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'failed'
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq('Call failed')
    transfer_attempt.call_end.should_not be_nil    
  end
  
  
  
end