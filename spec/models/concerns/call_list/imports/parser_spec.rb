require 'rails_helper'

describe 'CallList::Imports::Parser' do

  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list_redis.csv') }
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
    {
      saved_leads:        0,
      saved_numbers:      0,
      invalid_custom_ids: 0,
      cell_numbers:       Set.new,
      dnc_numbers:        Set.new,
      invalid_numbers:    Set.new,
      invalid_rows:       []
    }
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

  subject{ CallList::Imports::Parser.new(voter_list, cursor, results, batch_size) }

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
      context 'the first element' do
        it 'is an array of redis keys' do
          redis_keys = subject.parse_lines(data_lines.join).first

          expect(redis_keys).to eq(expected_redis_keys)
        end
      end

      context 'the second element' do
        it 'is a hash of parsed households' do
          parsed_households = subject.parse_lines(data_lines.join).last

          expect(parsed_households.keys).to eq ['1234567895', '4567123895']
        end
      end
    end

    context 'when a phone number is invalid' do
      let(:invalid_phone) do
        "98723"
      end
      let(:invalid_row) do
        %Q{#{invalid_phone},Sam,Iam,8th Old Man named Henry,,henry@test.com,193,42,Male}
      end
      before do
        d = data_lines.last
        d = d + "\n"
        data_lines[-1] = d
        lines_with_invalid = data_lines + [invalid_row]
        subject.parse_lines(lines_with_invalid.join)
      end

      it 'adds the invalid phone to results[:invalid_numbers]' do
        expect(subject.results[:invalid_numbers].to_a).to eq [invalid_phone]
      end

      it 'adds the invalid row to results[:invalid_rows]' do
        expect(subject.results[:invalid_rows]).to eq [invalid_row + "\n"]
      end
    end

    context 'when a custom id is invalid (eg blank)' do
      let(:invalid_row) do
        %Q{3927485021,Sam,Iam,8th Old Man named Henry,,henry@test.com,,42,Male}
      end
      before do
        d = data_lines.last
        d = d + "\n"
        data_lines[-1] = d
        lines_with_invalid = data_lines + [invalid_row]
        subject.parse_lines(lines_with_invalid.join)
      end

      it 'increments results[:invalid_custom_ids]' do
        expect(subject.results[:invalid_custom_ids]).to eq 1
      end

      it 'adds the invalid row to results[:invalid_rows]' do
        expect(subject.results[:invalid_rows]).to eq [invalid_row + "\n"]
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

    context 'cursor > 0' do
      let(:cursor){ 2 }
      subject{ CallList::Imports::Parser.new(voter_list, cursor, results, batch_size) }

      it 'parses headers from the first line' do
        expect(subject).to receive(:parse_headers).with(header_line).and_call_original
        subject.parse_file{ nil }
      end

      context 'only last line needs processing' do
        let(:cursor){ 3 } # valid_voters_list_redis has 1 header & 3 data rows
        subject{ CallList::Imports::Parser.new(voter_list, cursor, results, 1) }

        it 'parses the last line only' do
          expect(subject).to receive(:parse_lines).with(data_lines[-1..-1].join)
          subject.parse_file{ nil }
        end
      end

      context 'only first line has been processed' do
        let(:cursor){ 2 }
        subject{ CallList::Imports::Parser.new(voter_list, cursor, results, 1) }

        it 'parses all but the first line' do
          expect(subject).to receive(:parse_lines).with(data_lines[1..-1].join) # 0=header,1=first row
          subject.parse_file{ nil }
        end
      end
    end 
  end

  describe 'building business objects' do
    let(:uuid) do
      double('UUID', {
        generate: nil
      })
    end
    let(:household_uuid){ 'hh-uuid-123' }
    let(:lead_uuid){ 'ld-uuid-456' }
    let(:parsed_households) do
      subject.parse_lines(data_lines.join).last
    end
    let(:phone) do
      '1234567895'
    end

    before do
      expect(uuid).to receive(:generate).and_return(household_uuid).ordered
      expect(uuid).to receive(:generate).and_return(lead_uuid).ordered
      allow(UUID).to receive(:new){ uuid }
    end

    describe 'build_household' do
      it 'returns a hash w/ values for: leads, uuid, account_id, campaign_id, phone & blocked' do
        expected_household = {
          'uuid'        => household_uuid,
          'account_id'  => voter_list.account_id,
          'campaign_id' => voter_list.campaign_id,
          'phone'       => phone,
          'blocked'     => 0
        }

        expected_household.each do |k,v|
          expect(parsed_households[phone][k]).to eq v
        end
      end

      context 'voter_list.skip_wireless? => true && phone is a cellular device' do
        let(:dnc_wireless_list) do
          double('DoNotCall::WirelessList', {
            prohibits?: true
          })
        end

        before do
          allow(voter_list).to receive(:skip_wireless?){ true }
          allow(DoNotCall::WirelessList).to receive(:new){ dnc_wireless_list }
        end

        it 'sets "blocked" value to 1' do
          expect(parsed_households[phone]['blocked']).to eq 1
        end

        context 'phone is in customer DNC' do
          before do
            allow(voter_list.campaign).to receive(:blocked_numbers){ [phone] }
          end
          it 'sets "blocked" value to 3' do
            expect(parsed_households[phone]['blocked']).to eq 3
          end
        end
      end

      context 'phone is in customer DNC but not a cellular device' do
        before do
          allow(voter_list.campaign).to receive(:blocked_numbers){ [phone] }
        end
        it 'sets "blocked" value to 2' do
          expect(parsed_households[phone]['blocked']).to eq 2
        end
      end
    end

    describe 'build_lead' do
      after do
        @expected_first_lead.each do |k,v|
          expect(@first_lead[k]).to eq v
        end
      end

      it 'returns a hash that includes values for every non-nil, mapped value from the csv' do
        @first_lead          = parsed_households[phone]['leads'].first
        @expected_first_lead = {
          'first_name'    => 'Foo',
          'last_name'     => 'Bar',
          'middle_name'   => 'FuBur',
          'email'         => 'foo@bar.com',
          'custom_id'     => '987',
          'Age'           => '23',
          'Gender'        => 'Male'
        }
      end

      it 'returns a hash that includes values for: uuid, voter_list_id, account_id, campaign_id, phone & enabled' do
        @first_lead = parsed_households[phone]['leads'].first
        @expected_first_lead = { 
          'account_id'    => voter_list.account_id,
          'campaign_id'   => voter_list.campaign_id,
          'voter_list_id' => voter_list.id,
          'enabled'       => Voter.bitmask_for_enabled(:list),
          'uuid'          => lead_uuid,
          'phone'         => '1234567895',
        }
      end
    end
  end
end
