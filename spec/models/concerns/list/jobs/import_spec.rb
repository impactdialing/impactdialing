require 'rails_helper'

describe 'List::Jobs::Import' do
  subject{ List::Jobs::Import }

  let(:voter_list_mailer) do
    double('VoterListMailer', {
      completed: '',
      failed:    ''
    })
  end

  before do
    allow(VoterListMailer).to receive(:new){ voter_list_mailer }
  end

  describe '.perform(voter_list_id, email, cursor[0], results[nil])' do
    let(:results) do
      {
        numbers_tally: 0,
        leads_tally:   0
      }
    end
    let(:imports) do
      double('List::Imports', {
        parse:   nil,
        save:    nil,
        cursor:  6,
        results: results
      })
    end
    let(:voter_list){ create(:voter_list) }
    let(:cursor){ 0 }
    let(:email){ 'jo@test.com' }
    let(:redis_keys){ ['key1', 'key2'] }
    let(:parsed_households) do
      {
        '1234567890' => [{first_name: 'John', last_name: 'Doe'}],
        '4561237890' => [{first_name: 'Sally', last_name: 'Eod'}]
      }
    end

    before do
      allow(imports).to receive(:parse).and_yield(redis_keys, parsed_households)
      allow(List::Imports).to(receive(:new).with(voter_list, 0, nil)){ imports }
    end

    it 'calls List::Imports#parse to begin batch processing' do
      expect(imports).to receive(:parse)
      subject.perform(voter_list.id, email)
    end

    it 'sends VoterListMailer#completed email' do
      expect(voter_list_mailer).to receive(:completed).with(results)
      subject.perform(voter_list.id, email)
    end

    context 'each batch' do
      it 'calls List::Import#save(redis_keys, households)' do
        expect(imports).to receive(:save).with(redis_keys, parsed_households)
        subject.perform(voter_list.id, email)
      end
    end

    describe 'Termination' do
      let(:raise_args){ [Resque::TermException, "TERM"] }

      it 're-queues itself' do
        allow(imports).to receive(:parse).and_raise(*raise_args)

        subject.perform(voter_list.id, email)
        expect([:resque, :import]).to have_queued(subject).with(voter_list.id, email, 0, nil)
      end
      describe 'arguments when requeued' do
        before do
          allow(subject).to receive(:batch_size){ 1 }
          allow(subject).to receive(:mailer).and_raise(*raise_args)
        end
        after do
          expect([:resque, :import]).to have_queued(subject).with(voter_list.id, email, imports.cursor, imports.results.to_json)
        end
        it 'include `cursor` which points to the row following the last one processed' do
          subject.perform(voter_list.id, email)
        end
        it 'include `results` which is a json encoded string of the results as of the last row processed' do
          subject.perform(voter_list.id, email)
        end
      end
    end
  end
end
