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

  describe '#skip_pause=(bool)' do
    it 'sets :skip_pause on storage to one when bool is true' do
      subject.skip_pause = true
      expect(subject.storage[:skip_pause]).to eq '1'
    end
    it 'sets :skip_pause on storage to zero when bool is false' do
      subject.skip_pause = false
      expect(subject.storage[:skip_pause]).to eq '0'
    end 
  end

  describe '#skip_pause?' do
    it 'returns true when storage[:skip_pause] > 0' do
      subject.skip_pause = true
      expect(subject.skip_pause?).to be_truthy
    end
    it 'returns false when storage[:skip_pause] < 1' do
      subject.skip_pause = false
      expect(subject.skip_pause?).to be_falsey
    end
    it 'returns false when storage[:skip_pause] is not set' do
      expect(subject.skip_pause?).to be_falsey
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
    let(:dialed_call) do
      CallFlow::Call::Dialed.new(account_sid, dialed_call_sid)
    end
    let!(:caller_session_record) do
      create(:caller_session, sid: caller_session_sid)
    end
    it 'returns true when the caller is connected to another party' do
      dialed_call.storage[:status] = 'in-progress'
      subject.connect_to_lead(Forgery(:address).clean_phone, dialed_call_sid)

      expect(subject.in_conversation?).to be_truthy
    end
    it 'returns false when the caller is in a state other than On call' do
      subject.redirect_to_hold
      expect(subject.in_conversation?).to be_falsey
    end
    it 'returns false when the lead has disconnected' do
      dialed_call.storage[:status] = 'completed'
      subject.connect_to_lead(Forgery(:address).clean_phone, dialed_call_sid)
      expect(subject.in_conversation?).to be_falsey
    end
  end

  describe '#current_conversation_line_is?(questionable_call)' do
    # TransferController#disconnect (attempt_in_progress.id == transfer_attempt.call_attempt.id)
    it 'returns true when questionable_call has the same SID as the call the caller is currently connected to'
    it 'returns false when questionable_call does not have the same SID as the call the caller is currently connected to'
  end
end

