require "spec_helper"

describe TransferController do
  include Rails.application.routes.url_helpers
  def encode(str)
    URI.encode_www_form_component(str)
  end
  def request_body(from, to, url, fallback_url, status_callback)
    "From=#{from}&To=#{to}&Url=#{encode(url)}&FallbackUrl=#{encode(fallback_url)}&StatusCallback=#{encode(status_callback)}&Timeout=30"
  end

  before do
    WebMock.disable_net_connect!
  end

  describe '#dial' do
    let(:script){ create(:script) }
    let(:campaign) do
      create(:predictive, {
        script: script
      })
    end
    let(:transfer) do
      create(:transfer, {
        script: script,
        phone_number: "0987654321",
        transfer_type: Transfer::Type::WARM
      })
    end
    let(:call_attempt) do
      create(:call_attempt)
    end
    let(:call) do
      create(:call, {
        call_attempt: call_attempt
      })
    end
    let(:voter) do
      create(:voter, {
        phone: '1234567890'
      })
    end
    let(:caller_session) do
      create(:caller_session, {
        voter_in_progress: voter
      })
    end
    let(:call_sid){ '123123' }
    let(:twilio_url) do
      "api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}/Calls"
    end
    let(:fallback_url){ "blah" }
    let(:valid_twilio_response) do
      double('Response', {
        error?: false,
        call_sid: call_sid
      })
    end

    before do
      throw_away = TransferAttempt.create!
      url = "http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/transfer/#{throw_away.id + 1}/connect"
      status_callback = "http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/transfer/#{throw_away.id + 1}/end"
      stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
         with(:body => request_body(voter.phone, transfer.phone_number, url, fallback_url, status_callback)).
         to_return(:status => 200, :body => "", :headers => {})
      Providers::Phone::Twilio::Response.stub(:new){ valid_twilio_response }
      post :dial, transfer: {id: transfer.id}, caller_session: caller_session.id, call: call.id, voter: voter.id
    end

    it "renders json describing the type of transfer" do
      response.body.should eq("{\"type\":\"warm\"}")
    end
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
    url_opts = {
      :host => Settings.twilio_callback_host,
      :port => Settings.twilio_callback_port,
      :protocol => "http://"
    }
    campaign =  create(:preview)
    caller = create(:caller, {campaign: campaign})
    caller_session = create(:caller_session, campaign: campaign, session_key: "12345", caller: caller)
    call_attempt = create(:call_attempt, {
      sid: '123123'
    })
    transfer = create(:transfer, {
      phone_number: '1234567890'
    })
    transfer_attempt = create(:transfer_attempt, {
      caller_session: caller_session,
      call_attempt: call_attempt,
      transfer: transfer
    })
    Providers::Phone::Call.should_receive(:redirect).with(transfer_attempt.call_attempt.sid, callee_transfer_index_url(url_opts), {:retry_up_to => 5})
    Providers::Phone::Call.should_receive(:redirect).with(caller_session.sid, pause_caller_url(caller, url_opts.merge(session_id: caller_session.id)), {:retry_up_to => 5})

    post :connect, id: transfer_attempt.id
    transfer_attempt.reload
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