require 'rails_helper'

describe 'CallFlow::Persistence::SurveyResponses' do
  let(:dialed_call_storage) do
    instance_double('CallFlow::Call::Storage')
  end
  let(:dialed_call) do
    instance_double('CallFlow::Call::Dialed', {
      storage: dialed_call_storage
    })
  end
  let(:campaign) do
    instance_double('Predictive', {
      id: 42,
      type: 'Predictive'
    })
  end
  let(:household_record) do
    instance_double('Household', {id: 42})
  end
  let(:caller_record) do
    instance_double('Caller', {id: 43})
  end
  let(:caller_session) do
    instance_double('WebuiCallerSession', {id: 42, caller_id: caller_record.id})
  end
  let(:dispositioned_voter_record){ instance_double('Voter', {id: 42}) }
  let(:call_attempt_record){ instance_double('CallAttempt', {id: 45}) }

  before do
    allow(subject).to receive(:caller_session){ caller_session }
  end

  context 'when there is no data to save' do
    before do
      allow(dialed_call_storage).to receive(:attributes).and_return({
        mapped_status: CallAttempt::Status::VOICEMAIL,
        sid: 'dialed-call-sid',
        campaign_type: campaign.type,
        questions: {
          '' => 47,
          '13' => '',
          '14' => ''
        }.to_json,
        notes: {
          '' => 'Noteworthy'
        }.to_json
      })
    end

    describe '#save_answers' do
      subject{ CallFlow::Persistence::SurveyResponses.new(dialed_call, campaign, household_record) }
      it 'quietly no-ops' do
        expect{
          subject.save_answers(dispositioned_voter_record, call_attempt_record)
        }.to change{ Answer.count }.by(0)
      end
    end

    describe '#save_notes' do
      subject{ CallFlow::Persistence::SurveyResponses.new(dialed_call, campaign, household_record) }
      it 'quietly no-ops' do
        expect{
          subject.save_notes(dispositioned_voter_record, call_attempt_record)
        }.to change{ NoteResponse.count }.by(0)
      end
    end

    describe '#save' do
      subject{ CallFlow::Persistence::SurveyResponses.new(dialed_call, campaign, household_record) }
      it 'quietly no-ops' do
        expect{
          subject.save(dispositioned_voter_record, call_attempt_record)
        }.to change{ Answer.count + NoteResponse.count }.by(0)
      end
    end
  end

  context 'when there is data to save' do
    before do
      allow(dialed_call_storage).to receive(:attributes).and_return({
        mapped_status: CallAttempt::Status::SUCCESS,
        sid: 'dialed-call-sid',
        campaign_type: campaign.type,
        questions: {
          '12' => 47,
          '13' => 52,
          '14' => 74
        }.to_json,
        notes: {
          '42' => 'Noteworthy'
        }.to_json
      })
    end
    describe '#save_answers' do
      subject{ CallFlow::Persistence::SurveyResponses.new(dialed_call, campaign, household_record) }
      it 'creates an Answer record for every question_id => possible_response_id key/value pair in redis :questions' do
        expect{
          subject.save_answers(dispositioned_voter_record, call_attempt_record)
        }.to change{ Answer.count }.by JSON.parse(dialed_call_storage.attributes[:questions]).values.size
      end

      it 'sets proper associations for all Answer records' do
        subject.save_answers(dispositioned_voter_record, call_attempt_record)
        Answer.where(1).to_a.each do |answer|
          expect(answer.campaign_id).to eq campaign.id
          expect(answer.voter_id).to eq dispositioned_voter_record.id
          expect(answer.caller_id).to eq caller_session.caller_id
          expect(answer.call_attempt_id).to eq call_attempt_record.id
        end
      end

      it 'stores proper question => possible response associations' do
        subject.save_answers(dispositioned_voter_record, call_attempt_record)
        call_data = dialed_call_storage.attributes
        JSON.parse(call_data[:questions]).each do |question_id, possible_response_id|
          expect(Answer.where(question_id: question_id, possible_response_id: possible_response_id).count).to eq 1
        end
      end

    end

    describe '#save_notes' do
      subject{ CallFlow::Persistence::SurveyResponses.new(dialed_call, campaign, household_record) }
      it 'creates a NoteResponse record for every note_id => user_entered_text key/value pair in redis :notes' do
        subject.save_notes(dispositioned_voter_record, call_attempt_record)
        call_data = dialed_call_storage.attributes
        JSON.parse(call_data[:notes]).each do |note_id, note_text|
          expect(NoteResponse.where(note_id: note_id, response: note_text).count).to eq 1
        end
      end
    end
  end
end

