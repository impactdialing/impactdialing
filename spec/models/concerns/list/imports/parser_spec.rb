require 'rails_helper'

describe 'List::Imports::Parser' do

  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list.csv') }
    let(:windoze_csv_file_upload){ cp_tmp('windoze_voters_list.csv') }
  end

  let(:voter_list) do
    create(:voter_list, {
      csv_to_system_map: {
        'Phone'      => 'phone',
        'FIRSTName'  => 'first_name',
        'LAST'       => 'last_name',
        'MiddleName' => 'middle_name',
        'Suffix'     => 'suffix',
        'Email'      => 'email',
        'ID'         => 'custom_id',
        'Age'        => 'Age',
        'Gender'     => 'Gender'
      }
    })
  end

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
  let(:key_prefix){ "dial_queue:#{voter_list.campaign_id}:households:active" }

  let(:cursor){ 0 }
  let(:results) do
    {saved_leads: 0, saved_numbers: 0}
  end
  let(:batch_size){ ENV['VOTER_BATCH_SIZE'].to_i }

  let(:data_lines) do
    file.rewind
    lines = file.readlines
    subject.parse_headers(lines[0])
    lines[1..-1]
  end

  let(:header_line) do
    file.rewind
    file.readlines.first
  end

  let(:expected_redis_keys) do
    [
      "dial_queue:#{voter_list.campaign_id}:households:active:1234567",
      "dial_queue:#{voter_list.campaign_id}:households:active:4567123"
    ]
  end

  before do
    file.rewind
    allow(s3).to receive(:stream).and_yield(file.read)
    allow(AmazonS3).to receive(:new){ s3 }
  end

  subject{ List::Imports::Parser.new(voter_list, cursor, results, batch_size) }

  describe 'initialize' do
    it 'exposes csv_mapping instance' do
      expect(subject.csv_mapping).to be_kind_of CsvMapping
    end
    it 'exposes batch_size' do
      expect(subject.batch_size).to eq ENV['VOTER_BATCH_SIZE'].to_i
    end
    it 'exposes voter_list instance' do
      expect(subject.voter_list).to eq voter_list
    end
    it 'exposes results hash' do
      expect(subject.results).to be_kind_of Hash
    end
  end

  describe 'parse_headers' do
    it 'sets @phone_index to mark the location of phone data in csv file' do
      subject.parse_headers(header_line)
      expect(subject.instance_variable_get('@phone_index')).to eq 0
    end

    it 'populates @header_index_map to mark location of all column data in csv file' do
      subject.parse_headers(header_line)
      expect(subject.instance_variable_get('@header_index_map')).to eq({
        'Phone'      => 0,
        'FIRSTName'  => 1,
        'LAST'       => 2,
        'MiddleName' => 3,
        'Suffix'     => 4,
        'Email'      => 5,
        'ID'         => 6,
        'Age'        => 7,
        'Gender'     => 8
      })
    end
  end

  describe 'parse_lines' do
    describe 'returns a 2-element array where' do      
      it 'an array of redis keys is the first element' do
        redis_keys = subject.parse_lines(data_lines.join).first

        expect(redis_keys).to eq(expected_redis_keys)
      end

      it 'a hash of parsed households is the second element' do
        parsed_households = subject.parse_lines(data_lines.join).last

        first_lead = parsed_households['1234567895']['leads'].first
        expect(first_lead['first_name']).to eq "Foo"
        expect(first_lead['last_name']).to eq "Bar"
        expect(first_lead['middle_name']).to eq "FuBur"
        expect(first_lead['email']).to eq "foo@bar.com"
        expect(first_lead['custom_id']).to eq "987"
        expect(first_lead['Age']).to eq "23"
        expect(first_lead['Gender']).to eq "Male"
      end
    end
  end

  describe 'parse_file' do
    it 'parses headers from the first line' do
      expect(subject).to receive(:parse_headers).with(header_line).and_call_original
      subject.parse_file{ nil }
    end
    it 'parses data from subsequent lines' do
      expect(subject).to receive(:parse_lines).with(data_lines.join)
      subject.parse_file{ nil }
    end
    it 'yields keys, households, cursor, results' do
      expected_cursor = cursor + 1 + data_lines.size # 1 => header line
      expect{|b| subject.parse_file(&b) }.to yield_with_args(expected_redis_keys, Hash, expected_cursor, Hash)
    end
  end
end
