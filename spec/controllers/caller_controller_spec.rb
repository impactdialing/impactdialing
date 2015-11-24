require 'rails_helper'

describe CallerController, :type => :controller do

  let(:account) { create(:account) }
  let(:user) { create(:user, :account => account) }

  before do
    webmock_disable_net!
  end

  describe "authentication" do
    let(:campaign) do
      create(:campaign, {
        start_time: Time.now - 6.hours,
        end_time: Time.now + 6.hours
      })
    end

    before(:each) do
      @caller = create(:caller, {
        account: account,
        campaign: campaign
      })
      login_as(@caller)
    end

    it "logs out" do
      post :logout
      expect(session[:caller]).to be_nil
      expect(response).to redirect_to(callveyor_login_path)
    end
  end

  describe "Preview dialer" do
    let(:campaign) do
      create(:preview, {
        start_time: Time.now,
        end_time: Time.now,
        account: account
      })
    end
    let(:caller) do
      create(:caller, {
        campaign: campaign
      })
    end
    let(:caller_session) do
      create(:webui_caller_session, {
        caller: caller,
        campaign: campaign
      })
    end
    let(:current_voter) do
      create(:voter, {
        campaign: campaign
      })
    end
    let(:next_voter) do
      create(:voter, {
        campaign: campaign
      })
    end
    let(:valid_params) do
      {
        id: caller.id,
        session_id: caller_session.id,
        voter_id: current_voter.id
      }
    end

    describe 'POST caller/:id/skip_voter, session_id:, voter_id:' do
      include FakeCallData
      include ListHelpers

      let(:voter_list){ create(:voter_list, campaign: campaign) }
      let(:household) do
        build_household_hash(voter_list)
      end

      before do
        login_as(caller)
        allow(caller_session).to receive(:campaign){ campaign }
        allow(CallerSession).to receive_message_chain(:includes, :where, :first){ caller_session }
      end

      context 'when fit to dial' do
        before do
          allow(caller_session).to receive(:fit_to_dial){ true }
          allow(campaign).to receive(:caller_conference_started_event){ {data: household} }
        end
        it 'renders next lead (voter) data' do
          post :skip_voter, valid_params
          expect(response.body).to eq household.to_json
        end
      end

      context 'when not fit to dial' do
        before do
          allow(caller_session).to receive(:fit_to_dial?){ false }
          allow(CallerSession).to receive_message_chain(:includes, :where, :first){ caller_session }
          allow(caller).to receive(:campaign){ campaign }
          allow(Caller).to receive(:find){ caller }
          allow(campaign).to receive(:time_period_exceeded?){ true }
        end

        it 'queues RedirectCallerJob, relying on calculated redirect url to return :dialing_prohibited' do
          post :skip_voter, valid_params
          expect([:sidekiq, :call_flow]).to have_queued(RedirectCallerJob).with(caller_session.id) 
        end

        it 'renders abort json' do
          expected_json = {
            message: I18n.t('dialer.campaign.time_period_exceeded', {
              start_time: "#{campaign.start_time.strftime('%l %p').strip}",
              end_time: "#{campaign.end_time.strftime('%l %p').strip}"
            })
          }.to_json

          post :skip_voter, valid_params
          expect(response.body).to eq(expected_json)
          expect(response.status).to eq 403
        end
      end
    end
  end

  describe "call voter" do
    it "should call voter" do
      account         = create(:account)
      campaign        = create(:predictive, account: account)
      caller          = create(:caller, campaign: campaign, account: account)
      caller_identity = create(:caller_identity)
      voter           = create(:voter, campaign: campaign)
      caller_session  = create(:webui_caller_session, {
        session_key: caller_identity.session_key,
        caller_type: CallerSession::CallerType::TWILIO_CLIENT,
        caller: caller,
        campaign: campaign
      })

      expect(CallerPusherJob).to receive(:add_to_queue).with(caller_session, 'publish_calling_voter')

      post :call_voter, id: caller.id, phone: voter.household.phone, session_id: caller_session.id

      expect([:sidekiq, :call_flow]).to have_queued(PreviewPowerDialJob).with(caller_session.id, "#{voter.household.phone}")
    end
  end

  describe "kick id:, caller_session:, participant_type:" do
    let(:account){ create(:account) }
    let(:campaign){ create(:predictive, account: account) }
    let(:caller){ create(:caller, campaign: campaign, account: account) }
    let(:caller_identity){ create(:caller_identity) }
    let(:voter){ create(:voter, campaign: campaign) }

    let(:transfer_attempt) do
      create(:transfer_attempt)
    end
    let(:caller_session) do
      create(:webui_caller_session, {
        session_key: caller_identity.session_key,
        caller_type: CallerSession::CallerType::TWILIO_CLIENT,
        caller: caller,
        campaign: campaign,
        sid: '123abc',
        transfer_attempts: [transfer_attempt]
      })
    end
    let(:url_opts) do
      {
        host: Settings.twilio_callback_host,
        port: Settings.twilio_callback_port,
        protocol: "http://",
        session_id: caller_session.id
      }
    end
    let(:conference_sid){ 'CFww834eJSKDJFjs328JF92JSDFwe' }
    let(:conference_name){ caller_session.session_key }
    let(:valid_params) do
      {
        id: caller.id,
        caller_session_id: caller_session.id
      }
    end
    before do
      session[:caller] = caller.id
      stub_twilio_conference_by_name_request
    end
    shared_examples_for 'caller kicks self from transfer conference' do
      it 'kicks caller off conference' do
        expect(@kick_request).to have_been_made
      end
      it 'redirects caller to pause url' do
        expect(@redirect_request).to have_been_made
      end
      it 'renders nothing' do
        expect(response.body).to be_blank
      end
    end

    context 'caller' do
      let(:call_sid){ caller_session.sid }
      before do
        stub_twilio_kick_participant_request(conference_sid, call_sid)
        post_body = pause_caller_url(caller, url_opts)
        stub_twilio_redirect_request(post_body)
        post :kick, valid_params.merge(participant_type: 'caller')
      end

      it_behaves_like 'caller kicks self from transfer conference'
    end

    context 'transfer' do
      let(:call_sid){ transfer_attempt.sid }
      before do
        stub_twilio_kick_participant_request(conference_sid, call_sid)
        post :kick, valid_params.merge(participant_type: 'transfer')
      end

      it 'kicks transfer off conference' do
        expect(@kick_request).to have_been_made
      end
      it 'renders nothing' do
        expect(response.body).to be_blank
      end
    end

    context 'caller but transfer_attempt is nil' do
      # this is a purely to help out clients who get out of sync
      # eg hanging on to previous transfer states.
      let(:call_sid){ caller_session.sid }
      before do
        TransferAttempt.destroy_all
        stub_twilio_kick_participant_request(conference_sid, call_sid)
        post_body = pause_caller_url(caller, url_opts)
        stub_twilio_redirect_request(post_body)
        post :kick, valid_params.merge(participant_type: 'caller')
      end

      it_behaves_like 'caller kicks self from transfer conference'
    end
  end

  describe 'Caller TwiML' do
    let(:campaign){ create(:power) }
    let(:caller){ create(:caller, campaign: campaign) }
    let(:caller_session) do
      create(:webui_caller_session, {
        session_key: 'caller-session-key',
        campaign:    campaign,
        caller:      caller
      })
    end
    let(:caller_session_key){ caller_session.session_key }
    let(:transfer_session_key){ 'transfer-attempt-session-key' }
    let(:session_id){ caller_session.id }
    let(:params) do
      {
        id: caller.id,
        session_id: session_id
      }
    end

    describe '#pause id:, session_id:, CallSid:, clear_active_transfer:' do
      let(:action){ :pause }
      let(:processed_response_body_expectation) do
        Proc.new{ say('Please enter your call results.').and_pause(length: 600) }
      end

      it_behaves_like 'processable twilio fallback url requests'

      context 'caller arrives here and #skip_pause? => false' do
        before do
          post :pause, id: caller.id, session_id: session_id
        end
        it 'Says: "Please enter your call results."' do
          expect(response.body).to say('Please enter your call results.').
            and_pause(length: 600)
        end
      end

      context 'caller arrives here and #skip_pause? => true' do
        before do
          caller_session.skip_pause = true
          post :pause, id: caller.id, session_id: session_id
        end
        it 'Plays silence for 0.5 seconds' do
          expect(response.body).to include '<Play digits="www"/>'
        end
      end
    end

    describe '#continue_conf' do
      let(:dial_options) do
        {
          hangupOnStar: true,
          action: pause_caller_url(caller.id, caller_session.default_twiml_url_params)
        }
      end
      let(:conference_options) do
        {
          name: caller_session_key,
          startConferenceOnEnter: false,
          endConferenceOnExit: true,
          beep: true,
          waitUrl: HOLD_MUSIC_URL,
          waitMethod: 'GET'
        }
      end
      let(:action){ :continue_conf }
      let(:processed_response_body_expectation) do
        Proc.new{ dial_conference(dial_options, conference_options) }
      end

      it_behaves_like 'processable twilio fallback url requests'
      it_behaves_like 'unprocessable caller twilio fallback url requests'
    end

    describe '#end_session' do
      let(:caller_session){ create(:caller_session) }
      context '@caller_session is nil' do
        it 'hangs up' do
          post :end_session
          expect(response.body).to hangup
        end
      end
      context '@caller_session is not nil' do
        it 'hangs up' do
          post :end_session, caller_session_id: caller_session.id
          expect(response.body).to hangup
        end
      end
    end
  end
end

