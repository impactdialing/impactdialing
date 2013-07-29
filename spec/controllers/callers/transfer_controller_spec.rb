require "spec_helper"

describe TransferController do

  it "should dial a number" do
    script =  create(:script)
    campaign = create(:predictive, script: script)
    transfer = create(:transfer, script: script, phone_number: "1234567890", transfer_type: Transfer::Type::WARM)
    caller_session = create(:caller_session)
    call_attempt = create(:call_attempt)
    call = create(:call, call_attempt: call_attempt)
    voter = create(:voter, Phone: "1234567890")
    Transfer.should_receive(:find).and_return(transfer)
    transfer.should_receive(:dial).with(caller_session, call_attempt, voter, Transfer::Type::WARM)
    post :dial, transfer: {id: transfer.id} , caller_session:  caller_session.id, call: call.id, voter: voter.id
    response.body.should eq("{\"type\":\"warm\"}")

  end

  it "should disconnect and set attempt status as success" do
    script =  create(:script)
    campaign = create(:predictive, script: script)

    caller_session = create(:caller_session, campaign: campaign, session_key: "12345")
    call_attempt = create(:call_attempt)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)

    post :disconnect, id: transfer_attempt.id
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq(CallAttempt::Status::SUCCESS)
  end

  it "should connect a call to a conference" do
    campaign =  create(:preview)
    caller_session = create(:caller_session, campaign: campaign, session_key: "12345")
    call_attempt = create(:call_attempt)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
    conferences = double
    Twilio::Conference.stub(:list).with({"FriendlyName" => caller_session.session_key}).and_return(conferences)
    conferences.stub(:parsed_response).and_return({"TwilioResponse"=>{"Conferences"=>{"Conference"=>{"Sid"=>"CFadf94e58259b8cdd13b711ad2d079820", "AccountSid"=>"AC422d17e57a30598f8120ee67feae29cd", "FriendlyName"=>"f71489ed2375c77db54ed9112b95d3901d5e48ce", "Status"=>"completed", "DateCreated"=>"Mon, 21 Nov 2011 09:20:54 +0000", "ApiVersion"=>"2010-04-01", "DateUpdated"=>"Mon, 21 Nov 2011 09:22:28 +0000", "Uri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences/CFadf94e58259b8cdd13b711ad2d079820", "SubresourceUris"=>{"Participants"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences/CFadf94e58259b8cdd13b711ad2d079820/Participants"}}, "page"=>"0", "numpages"=>"1", "pagesize"=>"50", "total"=>"1", "start"=>"0", "end"=>"0", "uri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce", "firstpageuri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce&Page=0&PageSize=50", "previouspageuri"=>"", "nextpageuri"=>"", "lastpageuri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce&Page=0&PageSize=50"}}})
    TransferAttempt.should_receive(:find).with(transfer_attempt.id.to_s).and_return(transfer_attempt)
    transfer_attempt.should_receive(:redirect_callee)
    Twilio.should_receive(:connect).with(TWILIO_ACCOUNT, TWILIO_AUTH).twice
    Twilio::Conference.should_receive(:kick_participant)
    post :connect, id: transfer_attempt.id
    transfer_attempt.connecttime.should_not be_nil
  end

  it "should hangup if callee is disconnected" do
    campaign =  create(:power)
    caller_session = create(:caller_session, campaign: campaign, session_key: "12345")
    call_attempt = create(:call_attempt, status: CallAttempt::Status::SUCCESS)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
    conferences = double
    Twilio::Conference.stub(:list).with({"FriendlyName" => caller_session.session_key}).and_return(conferences)
    conferences.stub(:parsed_response).and_return({"TwilioResponse"=>{"Conferences"=>{"Conference"=>{"Sid"=>"CFadf94e58259b8cdd13b711ad2d079820", "AccountSid"=>"AC422d17e57a30598f8120ee67feae29cd", "FriendlyName"=>"f71489ed2375c77db54ed9112b95d3901d5e48ce", "Status"=>"completed", "DateCreated"=>"Mon, 21 Nov 2011 09:20:54 +0000", "ApiVersion"=>"2010-04-01", "DateUpdated"=>"Mon, 21 Nov 2011 09:22:28 +0000", "Uri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences/CFadf94e58259b8cdd13b711ad2d079820", "SubresourceUris"=>{"Participants"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences/CFadf94e58259b8cdd13b711ad2d079820/Participants"}}, "page"=>"0", "numpages"=>"1", "pagesize"=>"50", "total"=>"1", "start"=>"0", "end"=>"0", "uri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce", "firstpageuri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce&Page=0&PageSize=50", "previouspageuri"=>"", "nextpageuri"=>"", "lastpageuri"=>"/2010-04-01/Accounts/AC422d17e57a30598f8120ee67feae29cd/Conferences?FriendlyName=f71489ed2375c77db54ed9112b95d3901d5e48ce&Page=0&PageSize=50"}}})

    post :connect, id: transfer_attempt.id
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
  end

  it "should end a successful call" do
    campaign =  create(:predictive)
    call_attempt = create(:call_attempt)
    caller_session = create(:caller_session, campaign: campaign, attempt_in_progress: call_attempt)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
    post :end, id: transfer_attempt.id, :CallStatus => 'completed'
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq('Call completed with success.')
    transfer_attempt.call_end.should_not be_nil
  end

  it "should end a no-answer call" do
    campaign =  create(:preview)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'no-answer'
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq('No answer')
    transfer_attempt.call_end.should_not be_nil
  end

  it "should end a busy call" do
    campaign =  create(:predictive)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'busy'
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq('No answer busy signal')
    transfer_attempt.call_end.should_not be_nil
  end

  it "should end a failed call" do
    campaign =  create(:power)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'failed'
    response.body.should eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    transfer_attempt.status.should eq('Call failed')
    transfer_attempt.call_end.should_not be_nil
  end



end