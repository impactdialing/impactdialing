require 'rails_helper'

describe TransferController, :type => :controller do
  include Rails.application.routes.url_helpers

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
      :dialed_call => dialed_call,
      :skip_pause= => nil
    })
  end
  let(:caller_record) do
    create(:caller)
  end
  let(:caller_session) do
    create(:caller_session, caller: caller_record)
  end
  let(:phone){ twilio_valid_to }

  before do
    allow(dialed_call_storage).to receive(:[]).with(:phone){ phone }
    allow(caller_session).to receive(:caller_session_call){ call_flow_caller_session }
    allow(CallerSession).to receive(:find){ caller_session }
  end

  describe '#dial' do
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

  describe '#disconnect' do
    let(:params) do
      {
        id: transfer_attempt.id
      }
    end
    let(:action){ :disconnect }
    let(:processed_response_body_expectation) do
      Proc.new{ hangup }
    end

    it_behaves_like 'processable twilio fallback url requests'
    it_behaves_like 'unprocessable lead twilio fallback url requests'

    it 'hangs up the transfer' do
      post :disconnect, params

      expect(response.body).to hangup
    end

    it 'updates TransferAttempt#status to SUCCESS' do
      post :disconnect, params

      transfer_attempt.reload
      expect(transfer_attempt.status).to eq(CallAttempt::Status::SUCCESS)
    end
  end

  describe '#caller' do
    let(:params) do
      {
        id: transfer_attempt.id,
        caller_session: caller_session.id,
        session_key: transfer_attempt.session_key
      }
    end
    let(:action){ :caller }
    let(:processed_response_template) do
      'transfer/caller'
    end

    it_behaves_like 'processable twilio fallback url requests'
    it_behaves_like 'unprocessable caller twilio fallback url requests'

    it 'renders transfer/caller' do
      post action, params
      expect(response).to render_template processed_response_template
    end
  end

  describe '#callee' do
    let(:params) do
      {
        id: transfer_attempt.id,
        caller_session: caller_session.id,
        session_key: transfer_attempt.session_key
      }
    end
    let(:action){ :callee }
    let(:processed_response_template) do
      'transfer/callee'
    end

    it_behaves_like 'processable twilio fallback url requests'
    it_behaves_like 'unprocessable lead twilio fallback url requests'

    it 'renders transfer/callee' do
      post action, params
      expect(response).to render_template processed_response_template
    end
  end

  describe '#connect' do
    let(:caller_record){ create(:caller) }
    let(:twilio_response) do
      instance_double('Providers::Phone::Twilio::Response', {error?: false})
    end
    let(:url_opts) do
      {
        :host => Settings.twilio_callback_host,
        :port => Settings.twilio_callback_port,
        :protocol => "http://"
      }
    end
    let(:action){ :connect }
    let(:params) do
      {
        id: transfer_attempt.id
      }
    end
    let(:conference_options) do
      {
        name: transfer_attempt.session_key,
        waitUrl: HOLD_MUSIC_URL,
        waitMethod: 'GET',
        beep: false,
        endConferenceOnExit: false
      }
    end
    let(:dial_options) do
      {
        hangupOnStar: 'false',
        action: disconnect_transfer_url(transfer_attempt, url_opts),
        record: caller_session.campaign.account.record_calls
      }
    end
    let(:processed_response_template) do
      'transfer/connect'
    end
    before do
      transfer.update_attributes(transfer_type: Transfer::Type::COLD)
      allow(transfer_attempt).to receive(:transfer_type){ Transfer::Type::COLD }
      allow(transfer_attempt).to receive(:caller_session){ caller_session }
      allow(TransferAttempt).to receive_message_chain(:includes, :find){ transfer_attempt }
      caller_record.caller_sessions << caller_session
      caller_record.save!
      allow(Providers::Phone::Call).to receive(:redirect).with(call_sid, callee_transfer_index_url(url_opts.merge(transfer_type: transfer_attempt.transfer_type)), {retry_up_to: ENV["TWILIO_RETRIES"]}){ twilio_response }
      allow(Providers::Phone::Call).to receive(:redirect).with(caller_session.sid, pause_caller_url(caller_record, url_opts.merge(session_id: caller_session.id)), {retry_up_to: ENV["TWILIO_RETRIES"]})
    end

    it_behaves_like 'processable twilio fallback url requests'
    it_behaves_like 'unprocessable lead twilio fallback url requests'

    it 'redirects the lead to the transfer conference' do
      expect(Providers::Phone::Call).to receive(:redirect).with(call_sid, callee_transfer_index_url(url_opts.merge(transfer_type: transfer_attempt.transfer_type)), {retry_up_to: ENV["TWILIO_RETRIES"]}){ twilio_response }

      post :connect, params
    end
    it 'redirects the caller to the transfer conference' do
      expect(Providers::Phone::Call).to receive(:redirect).with(caller_session.sid, pause_caller_url(caller_record, url_opts.merge(session_id: caller_session.id)), {retry_up_to: ENV["TWILIO_RETRIES"]})

      post :connect, params
    end
    it 'sets TransferAttempt#connecttime' do
      post :connect, params
      transfer_attempt.reload

      expect(transfer_attempt.connecttime).not_to be_nil
    end
    it 'tells caller to skip /pause' do
      expect(call_flow_caller_session).to receive(:skip_pause=).with(true)

      post :connect, params
    end

    it 'renders transfer/connect' do
      post :connect, params
      expect(response).to render_template processed_response_template
    end
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
