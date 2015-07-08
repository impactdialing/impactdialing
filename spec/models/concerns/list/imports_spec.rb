require 'rails_helper'

describe 'List::Imports' do  
  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list.csv') }
    let(:windoze_csv_file_upload){ cp_tmp('windoze_voters_list.csv') }
  end

  let(:voter_list){ create(:voter_list) }
  let(:s3) do
    double('AmazonS3', {
      stream: nil
    })
  end
  let(:csv_file_name) do
    csv_file_upload
  end
  let(:csv_file) do
    CSV.new(File.open(csv_file_upload).read)
  end
  let(:file) do
    File.open(csv_file_upload)
  end

  before do
    allow(s3).to receive(:stream).and_yield(file.read)
    allow(AmazonS3).to receive(:new){ s3 }
  end

  after do
    Redis.new.flushall
  end

  describe 'initialize' do
    subject{ List::Imports.new(voter_list) }

    it 'exposes batch_size int[ENV["VOTER_BATCH_SIZE"]|100]' do
      expect(subject.batch_size).to eq ENV['VOTER_BATCH_SIZE'].to_i
    end
    it 'exposes voter_list instance' do
      expect(subject.voter_list).to eq voter_list
    end
    it 'exposes csv_mapping instance' do
      expect(subject.csv_mapping).to be_kind_of CsvMapping
    end
    it 'exposes cursor int' do
      expect(subject.cursor).to eq 0
    end
    it 'exposes results hash' do
      expect(subject.results).to be_kind_of Hash
    end

    context 'default @results hash' do
      subject{ List::Imports.new(voter_list) }

      it 'saved_numbers => 0' do
        expect(subject.results[:saved_numbers]).to be_zero
      end
      it 'total_numbers => 0' do
        expect(subject.results[:total_numbers]).to be_zero
      end
      it 'saved_leads => 0' do
        expect(subject.results[:saved_leads]).to be_zero
      end
      it 'total_leads => 0' do
        expect(subject.results[:total_leads]).to be_zero
      end
      it 'new_numbers => Set.new' do
        expect(subject.results[:new_numbers]).to eq Set.new
      end
      it 'pre_existing_numbers => Set.new' do
        expect(subject.results[:pre_existing_numbers]).to eq Set.new
      end
      it 'dnc_numbers => Set.new' do
        expect(subject.results[:dnc_numbers]).to eq Set.new
      end
      it 'cell_numbers => Set.new' do
        expect(subject.results[:cell_numbers]).to eq Set.new
      end
      it 'new_leads => 0' do
        expect(subject.results[:total_leads]).to be_zero
      end
      it 'updated_leads => 0' do
        expect(subject.results[:updated_leads]).to be_zero
      end
      it 'invalid_numbers => Set.new' do
        expect(subject.results[:invalid_numbers]).to eq Set.new
      end
      it 'invalid_rows => []' do
        expect(subject.results[:invalid_rows]).to eq []
      end
      it 'use_custom_id => false' do
        expect(subject.results[:use_custom_id]).to be_falsey
      end
    end

    context 'recover results from encoded string to initialize' do
      let(:expected_recovered_results) do
        {
          saved_numbers:        3,
          total_numbers:        10,
          saved_leads:          2,
          total_leads:          10,
          new_leads:            1,
          updated_leads:        1,
          new_numbers:          Set.new(['1234567890','4561237890']),
          pre_existing_numbers: Set.new(['1214567890','4561923780']),
          dnc_numbers:          Set.new,
          cell_numbers:         Set.new,
          invalid_numbers:      Set.new(['123','456']),
          invalid_rows:         [["123,Sam,McGee"],["456,Jasmine,Songbird"]],
          use_custom_id:        false
        }
      end
      let(:results_json){ expected_recovered_results.to_json }

      subject{ List::Imports.new(voter_list, 5, results_json) }

      it 'loads previous results instead of defaults' do
        expect(subject.results).to eq expected_recovered_results.stringify_keys
      end
    end
  end

  describe 'parse' do
    it 'yields array of redis keys as first arg'
    it 'yields parsed households (hash of leads grouped by phone) as second arg'
  end

  describe 'save' do
    subject{ List::Imports.new(voter_list) }

    it 'saves households & leads at given redis keys' do
      subject.parse do |redis_keys, households|
        subject.save(redis_keys, households)
      end
      # byebug
      expect(voter_list.campaign.dial_queue.households.exists?).to be_truthy
    end

    it 'returns an array [cursor(int), results(hash)]'
  end
end
