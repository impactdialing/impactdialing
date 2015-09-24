require 'rails_helper'

describe 'CallFlow::Call::Lead' do
  let(:account_sid){ 'AC-123' }
  let(:call_sid){ 'CA-321' }
  let(:caller_session_sid){ 'CA-214' }
  subject{ CallFlow::Call::Lead.new(account_sid, call_sid) }

  describe '#caller_session_sid=' do
    before do
      subject.caller_session_sid = caller_session_sid
    end
    it 'stores caller_session_sid' do
      expect(subject.storage[:caller_session_sid]).to eq caller_session_sid
    end
    it 'sends sid to #caller_session' do
      expect(subject.caller_session_call.dialed_call_sid).to eq call_sid
    end
  end

  describe '#caller_session' do
    it 'returns nil if @caller_session_sid is blank' do
      expect(subject.caller_session_call).to be_nil
    end
    it 'returns instance of CallFlow::CallerSession if @caller_session_sid is not blank' do
      subject.caller_session_sid = caller_session_sid
      expect(subject.caller_session_call).to be_kind_of CallFlow::CallerSession
    end
  end
end
