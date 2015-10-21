require 'rails_helper'

describe CallinController, :type => :controller do
  describe 'Caller Calling In' do
    let(:account) { create(:account, :activated => true) }
    let(:campaign) { create(:predictive, :account => account, :start_time => Time.new("2000-01-01 01:00:00"), :end_time => Time.new("2000-01-01 23:00:00"))}
    let(:pin){ 12345 }
    let(:caller) do
      create(:caller, :account => account, :campaign => campaign)
    end
    let(:caller_session) do
      create(:webui_caller_session, caller: caller, campaign: campaign)
    end
    let(:caller_identity) do
      create(:caller_identity, :caller => caller, :session_key => 'key' , pin: pin)
    end

    it 'renders twiml/caller_sessions/pin_prompt' do
      post :create
      expect(response).to render_template 'twiml/caller_sessions/pin_prompt'
    end

    context 'caller authenticates with PIN' do
      it "verifies the logged in caller by session pin" do
        allow(CallerIdentity).to receive(:find_by_pin).and_return(caller_identity)
        allow(caller_identity).to receive(:caller).and_return(caller)
        allow(caller).to receive(:create_caller_session).and_return(caller_session)
        allow(CallerSession).to receive(:find_by_id_cached).with(caller_session.id).and_return(caller_session)

        expect(RedisPredictiveCampaign).to receive(:add).with(caller.campaign_id, caller.campaign.type)
        expect(caller_session).to receive(:start_conf).and_return("")
        post :identify, Digits: pin, AccountSid: 'account-sid', CallSid: 'call-sid'
      end

      it 'creates a CallFlow::CallerSession redis record' do
        caller_identity
        params = {
          Digits: pin.to_s,
          AccountSid: 'account-sid',
          CallSid: 'call-sid',
          controller: 'callin',
          action: 'identify'
        }
        expect(CallFlow::CallerSession).to receive(:create).with(params)
        post :identify, params
      end

      it 'seeds redis script questions cache when caller is phones only' do
        caller = create(:caller, account: account, campaign: campaign, is_phones_only: true)
        caller_session = create(:phones_only_caller_session, {
          caller: caller,
          campaign: campaign,
          sid: 'caller-session-sid'
        })

        expect(Resque).to receive(:enqueue).with(CachePhonesOnlyScriptQuestions, anything, 'seed')
        post :identify, :Digits => caller.pin, :AccountSid => 'account-sid', :CallSid => 'call-sid'
      end

      it 'renders abort twiml unless the campaign is fit to start calling' do
        account.quota.update_attributes!(minutes_allowed: 0)
        expected_twiml = caller_session.account_has_no_funds_twiml

        post :identify, :Digits => caller.pin, :CallSid => 'caller-session-sid'
        expect(response.body).to eq expected_twiml
      end

      it 'renders abort twiml unless the caller is associated with a campaign' do
        caller.update_attributes!({campaign_id: nil})

        post :identify, :Digits => caller.pin, :CallSid => 'caller-session-key'

        expect(response).to render_template 'twiml/caller_sessions/campaign_missing'
      end
    end
    context 'caller fails to authenticate with PIN' do
      it "Prompts on incorrect pin" do
        allow(CallerIdentity).to receive(:find_by_pin).and_return(nil)
        post :identify, :Digits => pin, :attempt => "1"
        expect(response).to render_template 'twiml/caller_sessions/pin_prompt'
      end
    end

  end
end
