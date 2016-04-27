require 'rails_helper'

describe 'CallList::Imports::Parser' do
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
    instance_double('AmazonS3', {
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
      invalid_rows:       [],
      cell_rows:          [],
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
      "dial_queue:#{voter_list.campaign_id}:households:active:4567123",
      "list:#{voter_list.campaign_id}:custom_ids"
    ]
  end

  before do
    file.rewind
    contents = file.read
    allow(s3).to receive(:read){ contents }
    allow(AmazonS3).to receive(:new){ s3 }
  end

  subject{ CallList::Imports::Parser.new(voter_list, cursor, results, batch_size) }

  describe 'each_batch' do
    it 'yields keys, households, cursor, results' do
      header     = [[], {}, 1, results]
      line_one   = [[expected_redis_keys[0], expected_redis_keys[2]], Hash, 2, Hash]
      line_two   = [[expected_redis_keys[0], expected_redis_keys[2]], Hash, 3, Hash]
      line_three = [[expected_redis_keys[1], expected_redis_keys[2]], Hash, 4, Hash]
      expect{|b| subject.each_batch(&b) }.to yield_successive_args(header, line_one, line_two, line_three)
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
      allow(UUID).to receive(:new){ uuid }
    end

    describe 'build_household' do
      let(:row){ CSV::Row.new(['UUID','Phone'],[uuid,phone]) }
      before do
        expect(uuid).to receive(:generate).and_return(household_uuid).ordered
      end
      it 'returns a hash' do 
        expect(subject.build_household(uuid, phone, row)).to be_kind_of Hash
      end

      context 'the returned hash' do
        let(:the_hash){ subject.build_household(uuid, phone, row) }
        it '"leads" => []' do
          expect(the_hash['leads']).to eq []
        end
        it '"uuid" => UUID.new.generate' do
          expect(the_hash['uuid']).to eq household_uuid
        end
        it '"account_id" => voter_list.account_id' do
          expect(the_hash['account_id']).to eq voter_list.account_id
        end
        it '"campaign_id" => voter_list.campaign_id' do
          expect(the_hash['campaign_id']).to eq voter_list.campaign_id
        end
        it '"phone" => phone' do
          expect(the_hash['phone']).to eq phone
        end
        it '"blocked" => Integer' do
          expect(the_hash['blocked']).to eq 0
        end
      end

      context 'voter_list.skip_wireless? => true && phone is a cellular device' do
        let(:dnc_wireless_list) do
          double('DoNotCall::WirelessList', {
            prohibits?: true
          })
        end

        let(:the_hash){ subject.build_household(uuid, phone, row) }

        before do
          allow(voter_list).to receive(:skip_wireless?){ true }
          allow(DoNotCall::WirelessList).to receive(:new){ dnc_wireless_list }
        end

        it 'sets "blocked" value to 1' do
          expect(the_hash['blocked']).to eq 1
        end

        context 'phone is in customer DNC' do
          before do
            allow(voter_list.campaign).to receive(:blocked_numbers){ [phone] }
          end
          it 'sets "blocked" value to 3' do
            expect(the_hash['blocked']).to eq 3
          end
        end
      end

      context 'phone is in customer DNC but not a cellular device' do
        let(:the_hash){ subject.build_household(uuid, phone, row) }
        before do
          allow(voter_list.campaign).to receive(:blocked_numbers){ [phone] }
        end
        it 'sets "blocked" value to 2' do
          expect(the_hash['blocked']).to eq 2
        end
      end
    end

    describe 'build_lead' do
      let(:row) do
        %w{123-456-7895 Foo Bar FuBur Sr foo@bar.com 987 23 Male}
      end
      let(:the_hash){ subject.build_lead(uuid, phone, row, 0) }
      before do
        subject.parse_headers(header_line)
        expect(uuid).to receive(:generate).and_return(lead_uuid).ordered
      end

      def assert_the_hash(expected_hash)
        expected_hash.each do |prop,val|
          expect(the_hash[prop]).to eq val
        end
      end

      it 'returns a hash that includes values for every non-nil, mapped value from the csv' do
        assert_the_hash({
          'first_name'    => 'Foo',
          'last_name'     => 'Bar',
          'middle_name'   => 'FuBur',
          'email'         => 'foo@bar.com',
          'custom_id'     => '987',
          'Age'           => '23',
          'Gender'        => 'Male'
        })
      end

      it 'returns a hash that includes values for: uuid, voter_list_id, account_id, campaign_id, phone & enabled' do
        assert_the_hash({ 
          'account_id'    => voter_list.account_id,
          'campaign_id'   => voter_list.campaign_id,
          'voter_list_id' => voter_list.id,
          'enabled'       => Voter.bitmask_for_enabled(:list),
          'uuid'          => lead_uuid,
          'phone'         => '1234567895',
        })
      end

      context 'when a custom id is invalid (eg blank)' do
        let(:invalid_row) do
          %Q{3927485021,Sam,Iam,8th Old Man named Henry,"",henry@test.com,"",42,Male}
        end
        before do
          subject.build_lead(uuid, phone, CSV.new(invalid_row).first, 0)
        end

        it 'increments results[:invalid_custom_ids]' do
          expect(subject.results[:invalid_custom_ids]).to eq 1
        end

        it 'adds the invalid row to results[:invalid_rows]' do

          expect(subject.results[:invalid_rows]).to eq [invalid_row + "\n"]
        end
      end
    end
  end
end

