require 'rails_helper'

describe CallList::Parser do
  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list_redis.csv') }
    let(:windoze_csv_file_upload){ cp_tmp('windoze_voters_list.csv') }
    let(:bom_csv_file_upload){ cp_tmp('bom_voters_list.csv') }
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
      read: nil
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
      invalid_formats:    0,
      invalid_lines:      [],
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
      "dial_queue:#{voter_list.campaign_id}:households:active:1234567",
      "dial_queue:#{voter_list.campaign_id}:households:active:4567123"
    ]
  end

  before do
    file.rewind
    contents = file.read
    allow(s3).to receive(:read){ contents }
    allow(AmazonS3).to receive(:new){ s3 }
  end

  subject{ CallList::Parser.new(voter_list, cursor, results, batch_size) }
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

    it 'sets blank headers to VoterList::BLANK_HEADER' do
      with_blank = "#{header_line.chomp},,Birthday\n"
      subject.parse_headers(with_blank)
      mapped_headers = subject.instance_variable_get('@header_index_map')
      expect(mapped_headers[VoterList::BLANK_HEADER]).to eq mapped_headers.keys.size - 2
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
        it 'is an Array where each element has form [phone, csv_row, csv_row_index]' do
          data = subject.parse_lines(data_lines.join).last
          i = 0
          expected = data_lines.map do |line|
            csv_line = CSV.new(line).first
            phone    = csv_line[0].gsub(/[^\d]/,'')
            out      = [phone, csv_line, i]
            i += 1
            out
          end

          expect(data).to eq expected
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

    context 'when row data is malformed' do
      let(:invalid_row) do
        %Q{"2341235325","Jonathan "Johnny"", "Openheimer","","johnny@test.com",623,21,"Female"}
      end
      before do
        lines_with_invalid = data_lines + [invalid_row]
        subject.parse_lines(lines_with_invalid.join)
      end

      it 'increments results[:invalid_row_formats]' do
        expect(subject.results[:invalid_formats]).to eq 1
      end

      it 'adds the invalid row to results[:invalid_lines]' do
        expect(subject.results[:invalid_lines]).to eq [invalid_row + "\n"]
      end
    end
  end

  describe 'parse_file' do
    it 'parses headers from the first line' do
      expect(subject).to receive(:parse_headers).with(header_line).and_call_original
      subject.parse_file{ nil }
    end
    it 'parses data from subsequent lines' do
      expect(subject).to receive(:parse_lines).with('', {}).ordered
      data_lines.each do |line|
        expect(subject).to receive(:parse_lines).with(line, {}).ordered
      end
      subject.parse_file{ nil }
    end
    it 'yields keys, data, cursor, results' do
      header     = [[], [], 1, Hash]
      line_one   = [[expected_redis_keys[0]], Array, 2, Hash]
      line_two   = [[expected_redis_keys[1]], Array, 3, Hash]
      line_three = [[expected_redis_keys[2]], Array, 4, Hash]

      expect{|b| subject.parse_file(&b) }.to yield_successive_args(header, line_one, line_two, line_three)
    end

    context 'cursor > 0' do
      let(:cursor){ 2 }
      subject{ CallList::Parser.new(voter_list, cursor, results, batch_size) }

      it 'parses headers from the first line' do
        expect(subject).to receive(:parse_headers).with(header_line).and_call_original
        subject.parse_file{ nil }
      end

      context 'only last line needs processing' do
        let(:cursor){ 3 } # valid_voters_list_redis has 1 header & 3 data rows
        subject{ CallList::Parser.new(voter_list, cursor, results, 1) }

        it 'parses the last line only' do
          expect(subject).to receive(:parse_lines).with(data_lines[-1..-1].join, {})
          subject.parse_file{ nil }
        end

        context 'with batch size equal to cursor position' do
          subject{ CallList::Parser.new(voter_list, cursor, results, cursor) }
          it 'parses the last line only' do
            expect(subject).to receive(:parse_lines).with(data_lines[-1..-1].join, {})
            subject.parse_file{ nil }
          end
        end
      end

      context 'only first line has been processed' do
        let(:cursor){ 2 }
        subject{ CallList::Parser.new(voter_list, cursor, results, 1) }

        it 'parses all but the first line' do
          expect(subject).to receive(:parse_lines).with(data_lines[1], {}).ordered # 0=header,1=first row
          expect(subject).to receive(:parse_lines).with(data_lines[2], {}).ordered
          subject.parse_file{ nil }
        end
      end
    end 
    context 'bug: one or more headers are blank' do
      subject{ CallList::Imports::Parser.new(voter_list, 0, results, 5) }
      before do
        voter_list.update_attributes!({
          csv_to_system_map: voter_list.csv_to_system_map.merge({
            VoterList::BLANK_HEADER => 'address'
          })
        })
      end
      it 'skips that column' do
        expect{
          subject.parse_lines(data_lines.join)
        }.to_not raise_error
      end
    end

    context 'bug: when @header_index_map returns nil' do
      let(:csv_file) do
        CSV.new(File.open(bom_csv_file_upload).read)
      end
      let(:file) do
        File.open(bom_csv_file_upload)
      end
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

      let(:voter_list_two) do
        create(:voter_list, {
          campaign: voter_list.campaign,
          account: voter_list.account,
          csv_to_system_map: {
            "\xEF\xBB\xBFFirst Name" => 'first_name',
            "Last Name" => 'last_name',
            "# Windows" => "# of Windows",
            "Phone" => "phone",
            "Address" => "custom_id",
            "# Doors" => "",
            "Amount" => "",
            "Email" => "",
            "City" => "",
            "State" => "",
            "Zip" => "",
            "Sales Rep" => "",
            "Installer" => ""
          }
        })
      end
      subject{ CallList::Imports::Parser.new(voter_list_two, 0, results, 5) }

      it 'handles BOM characters' do
        expect{
          subject.parse_lines(data_lines.join)
        }.to_not raise_error
      end
    end
  end
end
