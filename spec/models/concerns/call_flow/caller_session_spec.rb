require 'rails_helper'

describe 'CallFlow::CallerSession' do
  let(:account_sid){ 'AC-123' }
  let(:caller_session_sid){ 'CA-321' }
  let(:dialed_call_sid){ 'CA-213' }
  subject{ CallFlow::CallerSession.new(account_sid, caller_session_sid) }

  it 'tracks the current state of a caller session'

  describe '#redirect_to_hold' do
    let(:caller_session_record){ create(:caller_session, sid: caller_session_sid) }
    before do
      subject.storage[:sid] = caller_session_record.sid
    end
    it 'queues RedirectCallerJob' do
      subject.redirect_to_hold
      expect([:sidekiq, :call_flow]).to have_queued(RedirectCallerJob).with(caller_session_record.id)
    end

    it 'sets RedisStatus to "On hold"' do
      subject.redirect_to_hold
      expect(RedisStatus.state_time(caller_session_record.campaign_id, caller_session_record.id).first).to eq 'On hold'
    end
  end

  describe '#stop_calling' do
    let(:caller_session_record){ double('CallerSession', {end_caller_session: nil, sid: caller_session_sid}) }
    before do
      allow(::CallerSession).to receive_message_chain(:where, :first){ caller_session_record }
    end

    it 'tells caller_session_record :end_caller_session' do
      expect(caller_session_record).to receive(:end_caller_session)
      subject.stop_calling
    end

    it 'queues EndRunningCallJob with caller session sid' do
      subject.stop_calling
      expect([:sidekiq, :call_flow]).to have_queued(EndRunningCallJob).with(caller_session_record.sid)
    end
  end

  describe '#dialed_call_sid=(dialed_call_sid)' do
    # Call#incoming_call (Twillio.set_attempt_in_progress)
    # Twillio.set_attempt_in_progress
    before do
      subject.dialed_call_sid = dialed_call_sid
    end

    it 'stores the connected call sid to redis' do
      expect(subject.storage[:dialed_call_sid]).to eq dialed_call_sid
    end

    it 'does not store blank values' do
      subject.dialed_call_sid = ''
      expect(subject.dialed_call_sid).to eq dialed_call_sid
    end
  end

  describe '#conversation_started(connected_call_sid)' do
    # Call#incoming_call (Twillio.set_attempt_in_progress)
    # Twillio.set_attempt_in_progress
    it 'sets status to "On call"'
  end

  describe '#dialed_call' do
    # PhonesOnlyCallerSession#submit_response
    # PhonesOnlyCallerSession#wrapup_call_attempt
    # PhonesOnlyCallerSession#call_answered?
    before do
      subject.dialed_call_sid = dialed_call_sid
    end

    it 'returns an instance of CallFlow::Lead after dialed_call_sid is set' do
      expect(subject.dialed_call).to be_kind_of CallFlow::Call::Dialed
    end
  end

  describe '#in_conversation?' do
    # Monitors::CallersController#start
    # TransferController#disconnect (attempt_in_progress != nil)
    # ModeratedSession#call_in_progress?
    it 'returns true when the caller is connected to another party'
    it 'returns false when the caller is not connected to another party'
  end

  describe '#current_conversation_line_is?(questionable_call)' do
    # TransferController#disconnect (attempt_in_progress.id == transfer_attempt.call_attempt.id)
    it 'returns true when questionable_call has the same SID as the call the caller is currently connected to'
    it 'returns false when questionable_call does not have the same SID as the call the caller is currently connected to'
  end
end

