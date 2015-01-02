require "spec_helper"

describe TransferController, :type => :controller do
  include Rails.application.routes.url_helpers
  def encode(str)
    URI.encode_www_form_component(str)
  end
  def request_body(from, to, url, fallback_url, status_callback)
    "From=#{from}&To=#{to}&Url=#{encode(url)}&StatusCallback=#{encode(status_callback)}&Timeout=15"
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
    let(:voter) do
      create(:voter)
    end
    let(:call_attempt) do
      create(:call_attempt, {household: voter.household})
    end
    let(:call) do
      create(:call, {
        call_attempt: call_attempt
      })
    end
    let(:caller_session) do
      create(:caller_session)
    end
    let(:call_sid){ '123123' }
    let(:twilio_url) do
      "api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}/Calls"
    end
    let(:fallback_url){ "blah" }
    let(:valid_twilio_response) do
      double('Response', {
        error?: false,
        call_sid: call_sid,
        content: {},
        success?: true
      })
    end

    before do
      throw_away      = TransferAttempt.create!
      url             = "http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/transfer/#{throw_away.id + 1}/connect"
      status_callback = "http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/transfer/#{throw_away.id + 1}/end"
      stub_request(:post, "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}").
         with(:body => request_body(voter.household.phone, transfer.phone_number, url, fallback_url, status_callback)).
         to_return(:status => 200, :body => "", :headers => {})
      allow(Providers::Phone::Twilio::Response).to receive(:new){ valid_twilio_response }
      post :dial, transfer: {id: transfer.id}, caller_session: caller_session.id, call: call.id, voter: voter.id
    end

    it "renders json describing the type of transfer" do
      expect(response.body).to eq("{\"type\":\"warm\",\"status\":\"Ringing\"}")
    end
  end

  it "should disconnect and set attempt status as success" do
    script =  create(:script)
    campaign = create(:predictive, script: script)

    caller_session = create(:caller_session, campaign: campaign, session_key: "12345")
    call_attempt = create(:call_attempt)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)

    post :disconnect, id: transfer_attempt.id
    expect(response.body).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq(CallAttempt::Status::SUCCESS)
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
    expect(Providers::Phone::Call).to receive(:redirect).with(transfer_attempt.call_attempt.sid, callee_transfer_index_url(url_opts), {retry_up_to: ENV["TWILIO_RETRIES"]})
    allow(RedisCallerSession).to receive(:any_active_transfers?).with(caller_session.session_key){ true }
    expect(Providers::Phone::Call).to receive(:redirect).with(caller_session.sid, pause_caller_url(caller, url_opts.merge(session_id: caller_session.id)), {retry_up_to: ENV["TWILIO_RETRIES"]})

    post :connect, id: transfer_attempt.id
    transfer_attempt.reload
    expect(transfer_attempt.connecttime).not_to be_nil
  end

  it "should end a successful call" do
    campaign =  create(:predictive)
    call_attempt = create(:call_attempt)
    caller_session = create(:caller_session, campaign: campaign, attempt_in_progress: call_attempt)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session, call_attempt: call_attempt)
    post :end, id: transfer_attempt.id, :CallStatus => 'completed'
    expect(response.body).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq('Call completed with success.')
    expect(transfer_attempt.call_end).not_to be_nil
  end

  it "should end a no-answer call" do
    campaign =  create(:preview)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'no-answer'
    expect(response.body).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq('No answer')
    expect(transfer_attempt.call_end).not_to be_nil
  end

  it "should end a busy call" do
    campaign =  create(:predictive)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'busy'
    expect(response.body).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq('No answer busy signal')
    expect(transfer_attempt.call_end).not_to be_nil
  end

  it "should end a failed call" do
    campaign =  create(:power)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'failed'
    expect(response.body).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Say voice=\"man\" language=\"en\" loop=\"1\">The transfered call was not answered </Say><Hangup/></Response>")
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq('Call failed')
    expect(transfer_attempt.call_end).not_to be_nil
  end



end