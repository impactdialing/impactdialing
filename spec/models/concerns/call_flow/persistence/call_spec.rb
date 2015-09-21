require 'rails_helper'

describe 'CallFlow::Persistence::Call' do
  describe '#create(dispositioned_voter_record)' do
    let(:dialed_call_storage) do
      instance_double('CallFlow::Call::Storage')
    end
    let(:dialed_call_state) do
      instance_double('CallFlow::Call::State', {
        time_visited: nil
      })
    end
    let(:dialed_call) do
      instance_double('CallFlow::Call::Dialed', {
        storage: dialed_call_storage,
        state: dialed_call_state
      })
    end
    let(:campaign) do
      instance_double('Predictive', {
        id: 42,
        type: 'Predictive'
      })
    end
    let(:empty_association_double) do
      double('Association', {
        where: []
      })
    end
    let(:household_record) do
      instance_double('Household', {
        id: 42,
        call_attempts: empty_association_double
      })
    end
    let(:caller_session){ nil }
    let(:dispositioned_voter_record){ nil }
    let(:call_attempt_record){ CallAttempt.last }

    subject{ CallFlow::Persistence::Call.new(dialed_call, campaign, household_record) }

    before do
      allow(dialed_call_storage).to receive(:attributes).and_return({
        mapped_status: CallAttempt::Status::BUSY,
        sid: 'dialed-call-sid',
        campaign_type: campaign.type
      })
    end

    shared_examples_for 'persisting any call attempt record' do
      it 'creates a CallAttempt record' do
        expect{
          subject.create_call_attempt(dispositioned_voter_record)
        }.to change{
          CallAttempt.count
        }.by 1
      end

      describe 'imported attributes' do
        it 'associates w/ proper Household record' do
          subject.create_call_attempt(dispositioned_voter_record)
          expect(call_attempt_record.household_id).to eq household_record.id
        end
        it 'associates w/ proper Campaign record' do
          subject.create_call_attempt(dispositioned_voter_record)
          expect(call_attempt_record.campaign_id).to eq campaign.id
        end
        it 'w/ mapped call status' do
          subject.create_call_attempt(dispositioned_voter_record)
          expect(call_attempt_record.status).to eq dialed_call_storage.attributes[:mapped_status]
        end
        it 'w/ sid' do
          subject.create_call_attempt(dispositioned_voter_record)
          expect(call_attempt_record.sid).to eq dialed_call_storage.attributes[:sid]
        end
        it 'w/ dialer_mode' do
          subject.create_call_attempt(dispositioned_voter_record)
          expect(call_attempt_record.dialer_mode).to eq campaign.type
        end
      end
    end

    context 'dispositioned_voter_record is nil' do
      it_behaves_like 'persisting any call attempt record'
    end

    context 'dispositioned_voter_record is not nil' do
      let(:dispositioned_voter_record){ instance_double('Voter', {id: 42}) }
      let(:household_record) do
        instance_double('Household', {
          id: 42,
          call_attempts: empty_association_double
        })
      end

      before do
        allow(dialed_call_state).to receive(:time_visited).and_return(2.minutes.ago.utc)
        allow(dialed_call_storage).to receive(:attributes).and_return({
          mapped_status: CallAttempt::Status::BUSY,
          sid: 'dialed-call-sid',
          campaign_type: campaign.type
        })
      end

      it_behaves_like 'persisting any call attempt record'

      it 'associates w/ proper Voter record' do
        subject.create_call_attempt(dispositioned_voter_record)
        expect(call_attempt_record.voter_id).to eq dispositioned_voter_record.id
      end

      context 'responses was just submitted but previous persistence attempt created CallAttempt record' do
        let(:call_attempt_double) do
          instance_double('CallAttempt', {
            update_attributes!: nil
          })
        end
        let(:non_empty_association_double) do
          double('Association', {
            where: [call_attempt_double]
          })
        end
        let(:household_record) do
          instance_double('Household', {
            id: 42,
            call_attempts: non_empty_association_double
          })
        end
        subject{ CallFlow::Persistence::Call.new(dialed_call, campaign, household_record) }
        it 'updates existing CallAttempt with matching SID' do
          expect{
            subject.create_call_attempt(dispositioned_voter_record)
          }.to change{ CallAttempt.count }.by(0)
        end
        it 'returns the created CallAttempt record' do
          expect(subject.create_call_attempt(dispositioned_voter_record)).to be_present
        end

      end
    end

    context 'caller_session is associated w/ dialed_call (Preview/Power)' do
      let(:caller_session) do
        instance_double('WebuiCallerSession', {
          id: 42,
          sid: 'caller-session-call-sid',
          caller_id: 42
        })
      end

      before do
        allow(CallerSession).to receive(:where).with(sid: caller_session.sid){ [caller_session] }
        allow(dialed_call_storage).to receive(:attributes).and_return({
          mapped_status: CallAttempt::Status::BUSY,
          sid: 'dialed-call-sid',
          campaign_type: campaign.type,
          caller_session_sid: caller_session.sid
        })
      end

      it_behaves_like 'persisting any call attempt record'

      it 'associates w/ proper CallerSession record' do
        subject.create_call_attempt
        expect(call_attempt_record.caller_session_id).to eq caller_session.id
      end
      it 'associates w/ proper Caller record' do
        subject.create_call_attempt
        expect(call_attempt_record.caller_id).to eq caller_session.caller_id
      end
    end

    context 'dialed call was transferred' do
      let(:transfer_attempt){ create(:transfer_attempt) }

      before do
        allow(dialed_call).to receive(:transfer_attempt_ids){ [transfer_attempt.id] }
        subject.create_call_attempt
      end

      it 'updates TransferAttempt records with CallAttempt#id' do
        subject.update_transfer_attempts(call_attempt_record)
        expect(transfer_attempt.reload.call_attempt).to eq call_attempt_record
      end
    end

    context 'dialed call was recorded' do
      before do
        allow(dialed_call_storage).to receive(:attributes).and_return({
          mapped_status: CallAttempt::Status::BUSY,
          sid: 'dialed-call-sid',
          campaign_type: campaign.type,
          recording_url: 'http://api.twilio.com/recordings/1.mp3',
          recording_duration: 42
        })
      end

      it_behaves_like 'persisting any call attempt record'

      it 'persists recording_url' do
        subject.create_call_attempt
        expect(call_attempt_record.recording_url).to eq dialed_call_storage.attributes[:recording_url]
      end

      it 'persists recording_duration' do
        subject.create_call_attempt
        expect(call_attempt_record.recording_duration).to eq dialed_call_storage.attributes[:recording_duration]
      end
    end

    context 'message was dropped automatically' do
      before do
        allow(dialed_call_storage).to receive(:attributes).and_return({
          mapped_status: CallAttempt::Status::BUSY,
          sid: 'dialed-call-sid',
          campaign_type: campaign.type,
          recording_id: 42,
          recording_delivered_manually: 0
        })
      end

      it_behaves_like 'persisting any call attempt record'

      it 'persists recording_id' do
        subject.create_call_attempt
        expect(call_attempt_record.recording_id).to eq dialed_call_storage.attributes[:recording_id]
      end

      it 'persists recording_delivered_manually' do
        subject.create_call_attempt
        expect(call_attempt_record.recording_delivered_manually).to be_falsey
      end
    end
  end
end

