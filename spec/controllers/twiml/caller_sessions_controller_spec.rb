require 'spec_helper'

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
        post :dialing_prohibited, caller_session_id: caller_session.id

        expected_endtime = Time.now

        caller_session.reload

        expect(caller_session.endtime).to be_within(1.second).of(expected_endtime)
        expect(caller_session.on_call).to be_falsy
        expect(caller_session.available_for_call).to be_falsy
        expect(RedisStatus.state_time(campaign.id, caller_session.id))
      end
    end

    context 'account not funded' do
      it 'speaks account not funded message'
    end

    context 'dialer access denied by internal admin' do
      it 'speaks account not funded message (thinking is: keep this message generic to avoid embarassing customers if we deny access accidentally or decide customer is not abusing us - no point letting any volunteers know of our suspicions)'
    end

    context 'outside calling hours' do
      it 'speaks outside calling hours message'
    end

    context 'seats not available' do
      it 'speaks seats not available message'
    end
  end
end