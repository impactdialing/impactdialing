require 'rails_helper'

describe 'VoterBatchImport' do  
  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_confusing_headers.csv') }
    let(:csv_file) do
      CSV.new(File.open(csv_file_upload).read)
    end
    let(:file) do
      File.open(csv_file_upload)
    end
    let(:bad_csv_map_with_custom_id) do
      {
        "PRIMARYID"           => "custom_id",
        "LASTNAME"            => "last_name",
        "FIRSTNAME"           => "first_name",
        "GENDER"              => "Gender",
        "AGE"                 => "Age",
        "PHONENUMBER"         => "phone",
        "WIRELESSPHONENUMBER" => "Phone 2"
      }
    end
    let(:bad_csv_map_without_custom_id) do
      {
        "LASTNAME"            => "last_name",
        "FIRSTNAME"           => "first_name",
        "GENDER"              => "Gender",
        "AGE"                 => "Age",
        "PHONENUMBER"         => "phone",
        "WIRELESSPHONENUMBER" => "Phone 2"
      }
    end
  end

  context 'with CustomID' do
    let(:mapping) do
      csv_mapping(bad_csv_map_with_custom_id)
    end

    describe 'initial upload returns a Hash with' do
      subject{ VoterBatchImport.new(voter_list, mapping, csv_file.shift, csv_file.readlines) }

      before do
        allow(VoterList).to receive(:read_from_s3).and_return(file.read)
        @counts = subject.import_csv
      end

      it 'invalid_numbers => ["row1","row2","row3"' do
        i            = 0
        invalid_rows = []
        IO.foreach(csv_file_upload) do |line|
          next if i .zero? && i += 1
          invalid_rows << line.gsub('"', '')
        end
        expect(@counts[:invalid_rows]).to eq invalid_rows
      end

      it 'saved_numbers => 0' do
        expect(@counts[:saved_numbers]).to eq 0
      end
    end

    describe '2nd upload returns a Hash with' do
      let(:csv_file_upload_with_duplicate_custom_id){ cp_tmp('voter_list_with_duplicate_custom_id_field.csv') }
      let(:dup_csv_file) do
        CSV.new(File.open(csv_file_upload_with_duplicate_custom_id).read)
      end
      let(:other_voter_list) do
        create(:voter_list, :campaign => campaign, :account => user.account)
      end
      let(:custom_fields) do
        {
          "Age" => "Age",
          "Gender" => "Gender"
        }
      end
      let(:map_with_custom_id_and_custom_fields) do
        map_with_custom_id.merge(custom_fields)
      end
      let(:valid_voters_map_with_custom_id_and_custom_fields) do
        CsvMapping.new(map_with_custom_id_and_custom_fields)
      end

      subject{ VoterBatchImport.new(voter_list, mapping, csv_file.shift, csv_file.readlines) }

      before(:each) do
        allow(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload_with_duplicate_custom_id}").read)
        batch_import = VoterBatchImport.new(other_voter_list, valid_voters_map_with_custom_id_and_custom_fields, dup_csv_file.shift, dup_csv_file.readlines)
        result = batch_import.import_csv
        expect(result[:saved_leads]).to eq 2
        expect(result[:saved_numbers]).to eq 1
        expect(result[:invalid_numbers]).to eq 0

        allow(VoterList).to receive(:read_from_s3).and_return(file.read)
        @counts = subject.import_csv
      end

      it 'invalid_numbers => 1 (only 1 unique number in list)' do
        expect(@counts[:invalid_numbers]).to eq 1
      end

      it 'saved_numbers => 0' do
        expect(@counts[:saved_numbers]).to eq 0
      end
    end
  end

  context 'without CustomID' do
    let(:mapping) do
      csv_mapping(bad_csv_map_without_custom_id)
    end
    before do
      allow(VoterList).to receive(:read_from_s3).and_return(file.read)
      @counts = subject.import_csv
    end

    subject{ VoterBatchImport.new(voter_list, mapping, csv_file.shift, csv_file.readlines) }

    describe 'returns a Hash with' do
      it 'invalid_numbers => 1 (only 1 unique number in list)' do
        expect(@counts[:invalid_numbers]).to eq 1
      end

      it 'saved_numbers => 0' do
        expect(@counts[:saved_numbers]).to eq 0
      end
    end
  end
end
