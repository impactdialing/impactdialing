require 'rails_helper'

describe TransferController, :type => :controller do
  include Rails.application.routes.url_helpers
  def encode(str)
    URI.encode_www_form_component(str)
  end
  def request_body(from, to, url, fallback_url, status_callback)
    "From=#{from}&To=#{to}&Url=#{encode(url)}&StatusCallback=#{encode(status_callback)}&Timeout=15"
  end

  let(:script){ create(:script) }
  let(:campaign) do
    create(:predictive, {
      script: script
    })
  end
  let(:transfer) do
    create(:transfer, {
      script: script,
      phone_number: twilio_valid_to,
      transfer_type: Transfer::Type::WARM
    })
  end
  let(:transfer_attempt) do
    create(:transfer_attempt, {
      caller_session: caller_session,
      transfer: transfer
    })
  end
  let(:call_sid){ '123123' }
  let(:dialed_call_storage) do
    instance_double('CallFlow::Call::Storage', {
      :[]= => nil
    })
  end
  let(:dialed_call) do
    instance_double('CallFlow::Call::Dialed', {
      storage: dialed_call_storage,
      transfer_attempted: nil,
      sid: call_sid
    })
  end
  let(:call_flow_caller_session) do
    instance_double('CallFlow::CallerSession', {
      dialed_call: dialed_call
    })
  end
  let(:caller_session) do
    create(:caller_session)
  end
  let(:phone){ twilio_valid_to }

  before do
    silence_warnings{
      TWILIO_ACCOUNT                = 'AC211da899fe0c76480ff2fc4ad2bbdc79'
      TWILIO_AUTH                   = '09e459bfca8da9baeead9f9537735bbf'
      ENV['TWILIO_CALLBACK_HOST']   = 'test.com'
      ENV['CALL_END_CALLBACK_HOST'] = 'test.com'
      ENV['INCOMING_CALLBACK_HOST'] = 'test.com'
    }

    allow(dialed_call_storage).to receive(:[]).with(:phone){ phone }
    allow(caller_session).to receive(:caller_session_call){ call_flow_caller_session }
    allow(CallerSession).to receive(:find){ caller_session }
  end

  after do
    silence_warnings{
      TWILIO_ACCOUNT                = "blahblahblah"
      TWILIO_AUTH                   = "blahblahblah"
      ENV['TWILIO_CALLBACK_HOST']   = 'test.com'
      ENV['CALL_END_CALLBACK_HOST'] = 'test.com'
      ENV['INCOMING_CALLBACK_HOST'] = 'test.com'
    }
  end

  describe '#dial' do
    let(:twilio_url) do
      "api.twilio.com/2010-04-01/Accounts/#{TWILIO_ACCOUNT}/Calls"
    end
    let(:twilio_auth_url) do
      "https://#{TWILIO_ACCOUNT}:#{TWILIO_AUTH}@#{twilio_url}"
    end
    let(:fallback_url){ "blah" }

    before do
      throw_away      = TransferAttempt.create!
      url_opts        = {
        host: Settings.twilio_callback_host,
        port: Settings.twilio_callback_port
      }
      url             = dial_transfer_index_url(throw_away.id + 1, url_opts)
      status_callback = end_transfer_url(throw_away.id + 1, url_opts)
      VCR.use_cassette('Dialing a warm transfer') do
        post :dial, transfer: {id: transfer.id}, caller_session: caller_session.id
      end
    end

    it "renders json describing the type of transfer" do
      expect(response.body).to eq("{\"type\":\"warm\",\"status\":\"Ringing\"}")
    end
  end

  it "should disconnect and set attempt status as success" do
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)

    post :disconnect, id: transfer_attempt.id
    expect(response.body).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Hangup/></Response>")
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq(CallAttempt::Status::SUCCESS)
  end

  it "should connect a call to a conference" do
    transfer.update_attributes(transfer_type: Transfer::Type::COLD)
    allow(transfer_attempt).to receive(:transfer_type){ Transfer::Type::COLD }
    allow(transfer_attempt).to receive(:caller_session){ caller_session }
    allow(TransferAttempt).to receive_message_chain(:includes, :find){ transfer_attempt }
    caller_record = create(:caller)
    caller_record.caller_sessions << caller_session
    caller_record.save!
    url_opts = {
      :host => Settings.twilio_callback_host,
      :port => Settings.twilio_callback_port,
      :protocol => "http://"
    }
    twilio_response = double('Providers::Phone::Twilio::Response', {error?: false})
    expect(Providers::Phone::Call).to receive(:redirect).with(call_sid, callee_transfer_index_url(url_opts.merge(transfer_type: transfer_attempt.transfer_type)), {retry_up_to: ENV["TWILIO_RETRIES"]}){ twilio_response }
    allow(RedisCallerSession).to receive(:any_active_transfers?).with(caller_session.session_key){ true }
    expect(Providers::Phone::Call).to receive(:redirect).with(caller_session.sid, pause_caller_url(caller_record, url_opts.merge(session_id: caller_session.id)), {retry_up_to: ENV["TWILIO_RETRIES"]})

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
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq('Call completed with success.')
    expect(transfer_attempt.call_end).not_to be_nil
  end

  it "should end a no-answer call" do
    campaign =  create(:preview)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'no-answer'
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq('No answer')
    expect(transfer_attempt.call_end).not_to be_nil
  end

  it "should end a busy call" do
    campaign =  create(:predictive)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'busy'
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq('No answer busy signal')
    expect(transfer_attempt.call_end).not_to be_nil
  end

  it "should end a failed call" do
    campaign =  create(:power)
    caller_session = create(:caller_session, campaign: campaign)
    transfer_attempt = create(:transfer_attempt, caller_session: caller_session)
    post :end, id: transfer_attempt.id, :CallStatus => 'failed'
    transfer_attempt.reload
    expect(transfer_attempt.status).to eq('Call failed')
    expect(transfer_attempt.call_end).not_to be_nil
  end



end
