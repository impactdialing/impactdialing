require 'rails_helper'

describe 'CallerEvents' do
  describe 'caller reassigned event' do
    let(:pusher_instance) do
      double('Pusher', {
        trigger: nil
      })
    end
    let(:campaign){ create(:power) }
    let(:web_caller) do
      create(:caller, {campaign: campaign})
    end
    let(:phones_only_caller) do
      create(:caller, {
        is_phones_only: true,
        campaign: campaign
      })
    end
    let(:webui_caller_session) do
      create(:bare_caller_session, :webui, :available, {
        caller: web_caller,
        campaign: campaign,
        sid: 'caller-session-sid-123'
      })
    end
    let(:phones_only_caller_session) do
      create(:bare_caller_session, :phones_only, :available, {
        caller: phones_only_caller,
        campaign: campaign
      })
    end

    before do
      allow(Pusher).to receive(:[]){ pusher_instance }
    end

    it 'returns immediately if caller is phones only' do
      expect(Pusher).to_not receive(:[])
      phones_only_caller_session.publish_caller_reassigned
    end

    describe 'the event' do
      it 'is named "caller_reassigned"' do
        expect(pusher_instance).to receive(:trigger).with('caller_reassigned', anything)
        webui_caller_session.publish_caller_reassigned
      end
    end
  end
end
