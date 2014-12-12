require "spec_helper"

describe CallerController, :type => :controller do

  before do
    WebMock.disable_net_connect!
  end

  let(:account) { create(:account) }
  let(:user) { create(:user, :account => account) }

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
        start_time: Time.now - 6.hours,
        end_time: Time.now - 6.hours,
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

      before do
        current_voter
        next_voter
        dial_queue = cache_available_voters(campaign)
        dial_queue.next(1) # pop the current_voter off the list
        login_as(caller)
      end
      shared_examples 'mark the lead (voter) as skipped' do
        it 'sets Voter#skipped_time' do
          expect(current_voter.skipped_time).to be_nil

          post :skip_voter, valid_params

          expect(current_voter.reload.skipped_time).not_to be_nil
        end
      end

      context 'when fit to dial' do
        it_behaves_like 'mark the lead (voter) as skipped'

        it 'renders next lead (voter) data' do
          post :skip_voter, valid_params
          expect(response.body).to eq next_voter.reload.info.to_json
        end
      end

      context 'when not fit to dial' do
        before do
          campaign.update_attributes!(start_time: Time.now - 3.hours, end_time: Time.now - 2.hours)
        end

        it_behaves_like 'mark the lead (voter) as skipped'

        it 'queues RedirectCallerJob, relying on calculated redirect url to return :dialing_prohibited' do
          expect(Voter.count).to eq 2
          expect(Sidekiq::Client).to receive(:push).with('queue' => 'call_flow', 'class' => RedirectCallerJob, 'args' => [caller_session.id])
          post :skip_voter, valid_params
        end

        it 'renders abort json' do
          campaign.reload

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

  describe "start calling" do
    it "should start a new caller conference" do
      account = create(:account)
      campaign = create(:predictive, account: account, start_time: Time.now.beginning_of_day, end_time: Time.now.end_of_day)
      caller = create(:caller, campaign: campaign, account: account)
      caller_identity = create(:caller_identity)
      caller_session = create(:webui_caller_session, session_key: caller_identity.session_key, caller_type: CallerSession::CallerType::TWILIO_CLIENT, caller: caller, campaign: campaign)
      expect(Caller).to receive(:find).and_return(caller)
      expect(caller).to receive(:create_caller_session).and_return(caller_session)
      expect(RedisPredictiveCampaign).to receive(:add).with(caller.campaign_id, caller.campaign.type)
      post :start_calling, caller_id: caller.id, session_key: caller_identity.session_key, CallSid: "abc"
      expect(response.body).to eq("<?xml version=\"1.0\" encoding=\"UTF-8\"?><Response><Dial hangupOnStar=\"true\" action=\"http://#{Settings.twilio_callback_host}:#{Settings.twilio_callback_port}/caller/#{caller.id}/pause?session_id=#{caller_session.id}\"><Conference startConferenceOnEnter=\"false\" endConferenceOnExit=\"true\" beep=\"true\" waitUrl=\"hold_music\" waitMethod=\"GET\"/></Dial></Response>")
    end
  end

  describe "call voter" do
    it "should call voter" do
      account = create(:account)
      campaign =  create(:predictive, account: account)
      caller = create(:caller, campaign: campaign, account: account)
      caller_identity = create(:caller_identity)
      voter = create(:voter, campaign: campaign)
      caller_session = create(:webui_caller_session, {
        session_key: caller_identity.session_key,
        caller_type: CallerSession::CallerType::TWILIO_CLIENT,
        caller: caller,
        campaign: campaign
      })
      expect(Caller).to receive(:find).and_return(caller)
      expect(caller).to receive(:calling_voter_preview_power)
      post :call_voter, id: caller.id, voter_id: voter.id, session_id: caller_session.id
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
    let(:valid_response) do
      double('TwilioResponseObject', {
        :[] => {
          'TwilioResponse' => {}
        },
        :conference_sid => conference_sid
      })
    end
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
    context 'participant_type: "caller"' do
      let(:call_sid){ caller_session.sid }
      before do
        stub_twilio_kick_participant_request
        post_body = pause_caller_url(caller, url_opts)
        stub_twilio_redirect_request(post_body)
        post :kick, valid_params.merge(participant_type: 'caller')
      end

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

    context 'participant_type: "transfer"' do
      let(:call_sid){ transfer_attempt.sid }
      before do
        stub_twilio_kick_participant_request
        post :kick, valid_params.merge(participant_type: 'transfer')
      end

      it 'kicks transfer off conference' do
        expect(@kick_request).to have_been_made
      end
      it 'renders nothing' do
        expect(response.body).to be_blank
      end
    end
  end

  describe '#pause session_id:, CallSid:, clear_active_transfer:' do
    let(:campaign){ create(:power) }
    let(:caller_session) do
      create(:webui_caller_session, {
        session_key: 'caller-session-key',
        campaign: campaign
      })
    end
    let(:caller_session_key){ caller_session.session_key }
    let(:transfer_session_key){ 'transfer-attempt-session-key' }
    let(:session_id){ caller_session.id }

    context 'caller arrives here after disconnecting from the lead' do
      before do
        expect(RedisCallerSession.party_count(transfer_session_key)).to eq 0
        post :pause, session_id: session_id
      end
      it 'Says: "Please enter your call results."' do
        expect(response.body).to have_content 'Please enter your call results.'
      end
    end

    context 'caller arrives here after dialing a warm transfer' do
      before do
        RedisCallerSession.activate_transfer(caller_session_key, transfer_session_key)
        expect(RedisCallerSession.party_count(transfer_session_key)).to eq -1
        post :pause, session_id: session_id
      end
      after do
        RedisCallerSession.deactivate_transfer(caller_session_key)
      end
      it 'Plays silence for 0.5 seconds' do
        expect(response.body).to include '<Play digits="w"/>'
      end
    end

    context 'caller arrives here after leaving a warm transfer' do
      before do
        RedisCallerSession.activate_transfer(caller_session_key, transfer_session_key)
        RedisCallerSession.add_party(transfer_session_key)
        expect(RedisCallerSession.party_count(transfer_session_key)).to eq 0
        post :pause, session_id: session_id, clear_active_transfer: true
      end
      after do
        RedisCallerSession.deactivate_transfer(caller_session_key)
      end
      it 'Says: "Please enter your call results."' do
        expect(response.body).to have_content 'Please enter your call results.'
      end
    end
  end
end
