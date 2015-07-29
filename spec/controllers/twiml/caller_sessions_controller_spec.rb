require 'rails_helper'

describe Twiml::CallerSessionsController do
  include FakeCallData

  describe 'POST :dialing_prohibited' do
    let(:admin){ create(:user) }
    let(:account){ admin.account }
    let(:campaign){ create_campaign_with_script(:bare_preview, account).last }
    let(:caller){ create(:caller, is_phones_only: false, account: account) }
    let(:caller_session) do
      create(:bare_caller_session, :webui, :available, {
        caller: caller,
        campaign: campaign
      })
    end

    before do
      account.quota.update_attributes(minutes_allowed: 0)
    end

    it 'ends the callers session' do
      expected_endtime = nil

      Timecop.freeze do
        post :dialing_prohibited, caller_session_id: caller_session.id, format: :xml

        expected_endtime = Time.now

        caller_session.reload

        expect(caller_session.endtime).to be_within(1.second).of(expected_endtime)
        expect(caller_session.on_call).to be_falsy
        expect(caller_session.available_for_call).to be_falsy
        expect(RedisStatus.state_time(campaign.id, caller_session.id)).to be_nil
      end
    end

    it 'sets @reason to caller_session.abort_dial_reason' do
      expect(caller_session).to receive(:abort_dial_reason){ :blah }
      allow(CallerSession).to receive(:find){ caller_session }
      post :dialing_prohibited, caller_session_id: caller_session.id, format: :xml
      expect(assigns[:reason]).to eq :blah
    end

    it 'renders twiml/caller_sessions/dialing_prohibited.xml' do
      post :dialing_prohibited, caller_session_id: caller_session.id, format: :xml
      expect(response).to render_template 'twiml/caller_sessions/dialing_prohibited'
    end
  end
end
