require 'rails_helper'

describe CallList::Imports::Parser do
  describe '#each_batch' do
    include_context 'voter csv import' do
      let(:csv_file_upload){ cp_tmp('valid_voters_list_redis.csv') }
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

    let(:file) do
      File.open(csv_file_upload)
    end

    let(:batch_size){ 1 }
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

    before do
      file.rewind
      allow(s3).to receive(:read){ file.read }
      allow(AmazonS3).to receive(:new){ s3 }
    end

    subject{ CallList::Imports::Parser.new(voter_list, cursor, results, batch_size) }

    it 'resets households after yielding each batch; avoids duplicate lead bug #112573907' do
      subject.each_batch do |household_keys, households, cursor, results|
        expect(households.keys.size).to be <= 1
      end
    end
  end
end
