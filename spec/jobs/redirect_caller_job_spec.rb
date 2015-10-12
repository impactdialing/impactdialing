require 'rails_helper'

describe 'RedirectCallerJob' do
  subject{ RedirectCallerJob.new }
  let(:caller_session){ create(:webui_caller_session) }

  context 'call is in-progress' do
    before do
      allow(subject).to receive(:call_in_progress?){ true }
    end
    describe '#perform(caller_session_id)' do
      let(:location){ :default }
      it 'redirects the caller to hold' do
        expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session, location)
        subject.perform(caller_session.id)
      end
    end

    describe '#perform(caller_session_id, :pause)' do
      let(:location){ :pause }
      it 'redirects the caller to pause' do
        expect(Providers::Phone::Call).to receive(:redirect_for).with(caller_session, location)
        subject.perform(caller_session.id, :pause)
      end
    end
  end

  context 'call is not in-progress' do
    before do
      allow(subject).to receive(:call_in_progress?){ false }
    end
    it 'does nothing' do
      expect(Providers::Phone::Call).to_not receive(:redirect_for)
      subject.perform(caller_session.id)
    end
  end
end
