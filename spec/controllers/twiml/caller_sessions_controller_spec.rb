require 'rails_helper'

describe Twiml::CallerSessionsController do
  include FakeCallData

  let(:admin){ create(:user) }
  let(:account){ admin.account }
  let(:campaign){ create_campaign_with_script(:bare_preview, account).last }
  let(:caller){ create(:caller, is_phones_only: false, account: account, campaign: campaign) }

  describe 'POST :create, caller_id: Caller#id' do
    let(:generated_session_key){ 'random-chars-here' }
    let(:twilio_params) do
      {
        CallSid: 'CA-caller-session-123',
        AccountSid: 'AC-321',
        caller_id: caller.id,
        session_key: generated_session_key
      }
    end
    let(:redis_caller_session) do
      CallFlow::CallerSession.new(twilio_params[:AccountSid], twilio_params[:CallSid])
    end

    before do
      # CallerIdentity is created when a web caller logs in
      caller.create_caller_identity(generated_session_key)
    end

    it 'creates a CallerSession for the Caller' do
      expect{ 
        post :create, twilio_params
      }.to change{ caller.caller_sessions.count }.from(0).to(1)
    end
    it 'creates a CallFlow::CallerSession for the Caller' do
      post :create, twilio_params
      expect(redis_caller_session.storage['session_key']).to eq generated_session_key
    end
    it 'updates sets RedisStatus to "On hold" for the new CallerSession' do
      post :create, twilio_params
      expect(RedisStatus.state_time(campaign.id, caller.caller_sessions.last.id).first).to eq 'On hold'
    end
    it 'tells CallerSession to #start_conf' do
      caller_session = create(:bare_caller_session, :webui, :available, caller: caller, campaign: campaign)
      expect(caller_session).to receive(:start_conf)
      expect(caller).to receive(:create_caller_session){ caller_session }
      allow(Caller).to receive_message_chain(:includes, :find){ caller }
      
      post :create, twilio_params
    end
    it 'sets @caller' do
      post :create, twilio_params
      expect(assigns[:caller]).to eq caller
    end
    it 'sets @caller_session' do
      post :create, twilio_params
      expect(assigns[:caller_session]).to eq caller.caller_sessions.first
    end
    it 'renders twiml/caller_sessions/create.xml.erb' do
      post :create, twilio_params
      expect(response).to render_template 'twiml/caller_sessions/create'
    end

    context 'Predictive mode' do
      before do
        campaign.type = 'Predictive'
        campaign.save!
      end

      it 'adds caller.campaign.id to RedisPredictiveCampaign' do
        post :create, twilio_params
        expect(RedisPredictiveCampaign.running_campaigns).to include campaign.id.to_s
      end
    end
  end

  describe 'POST :dialing_prohibited' do
    let(:caller_session) do
      create(:bare_caller_session, :webui, :available, {
        caller: caller,
        campaign: campaign,
        sid: 'caller-session-sid'
      })
    end

    before do
      account.quota.update_attributes(minutes_allowed: 0)
    end

    it 'ends the callers session' do
      expected_endtime = nil

      Timecop.freeze do
        post :dialing_prohibited, caller_session_id: caller_session.id

        expected_endtime = Time.now

        caller_session.reload

        expect(caller_session.endtime).to be_within(1.second).of(expected_endtime)
        expect(caller_session.on_call).to be_falsy
        expect(caller_session.available_for_call).to be_falsy
        expect(RedisStatus.state_time(campaign.id, caller_session.id)).to be_empty
      end
    end

    it 'sets @reason to caller_session.abort_dial_reason' do
      expect(caller_session).to receive(:abort_dial_reason){ :blah }
      allow(CallerSession).to receive(:find){ caller_session }
      post :dialing_prohibited, caller_session_id: caller_session.id
      expect(assigns[:reason]).to eq :blah
    end

    it 'renders twiml/caller_sessions/dialing_prohibited.xml' do
      post :dialing_prohibited, caller_session_id: caller_session.id
      expect(response).to render_template 'twiml/caller_sessions/dialing_prohibited'
    end
  end
end
