require 'spec_helper'

describe 'VoterBatchImport' do
  include_context 'voter csv import' do
    let(:csv_file_upload){ cp_tmp('valid_voters_list.csv') }
    let(:windoze_csv_file_upload){ cp_tmp('windoze_voters_list.csv') }
  end

  describe "upload voters list" do
    let(:custom_fields) do
      {
        "Age" => "Age",
        "Gender" => "Gender"
      }
    end
    let(:map_with_custom_id_and_custom_fields) do
      map_with_custom_id.merge(custom_fields)
    end
    let(:map_without_custom_id_with_custom_fields) do
      map_without_custom_id.merge(custom_fields)
    end
    let(:valid_voters_map_with_custom_id) do
      CsvMapping.new(map_with_custom_id)
    end
    let(:valid_voters_map_without_custom_id) do
      CsvMapping.new(map_without_custom_id)
    end
    let(:valid_voters_map_with_custom_id_and_custom_fields) do
      CsvMapping.new(map_with_custom_id_and_custom_fields)
    end
    let(:valid_voters_map_without_custom_id_with_custom_fields) do
      CsvMapping.new(map_without_custom_id_with_custom_fields)
    end
    let(:valid_voters_not_available_map_without_custom_id) do
      CsvMapping.new({
        "Phone"=>"phone",
        "Name"=>"",
        "Email"=>"email"
      })
    end
    let(:windoze_mappings) do
      CsvMapping.new({
        "FIRST" => "first_name",
        "Phone" => "phone",
        "Email" => "email"
      })
    end

    shared_examples 'all valid Voter uploads' do
      it 'creates 1 Household record per phone number associated w/ appropriate Account & Campaign' do
        phones = []
        CSV.foreach(csv_file_upload, headers: true, return_headers: false) do |row|
          phone, first_name, last_name, middle_name, suffix, email, id, age, gender = *row
          expect(Household.where(campaign_id: campaign.id, phone: phone.last.gsub(/[^\d]/,'')).count).to eq 1
        end
      end

      it 'creates 1 Voter record associated with the appropriate Account, Campaign, VoterList & Household for each valid CSV row' do
        CSV.foreach(csv_file_upload, headers: true, return_headers: false) do |row|
          phone, first_name, last_name, middle_name, suffix, email, id, age, gender = *row
          
          voter = Voter.find_by_email(email)
          
          expect(voter).to_not be_nil
          expect(voter.account_id).to eq campaign.account_id
          expect(voter.campaign_id).to eq campaign.id
          expect(voter.voter_list_id).to eq voter_list.id
          expect(voter.household_id).to eq Household.where(phone: phone.last.gsub(/[^\d]/,'')).first.id
        end
      end

      it 'each created Voter record has attributes matching corresponding CSV row' do
        CSV.foreach(csv_file_upload, headers: true, return_headers: false) do |row|
          phone, first_name, last_name, middle_name, suffix, email, id, age, gender = *row.map(&:last).flatten

          voter = Voter.find_by_email(email)

          expect(voter.first_name).to eq first_name
          expect(voter.last_name).to eq last_name
        end
      end
      it 'each created Voter record has :list bit enabled' do
        expect(Voter.with_enabled(:list).count).to eq Voter.count
      end
      describe 'returns a Hash with' do
        it 'success => int' do
          expect(@counts[:success]).to eq (Voter.count - @counts[:dnc])
        end
        it 'failed => int' do
          expect(@counts[:failed]).to eq 0
        end
      end
    end

    describe "viable CSV file" do
      before do
        Voter.destroy_all
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
      subject{ VoterBatchImport.new(voter_list, mapping, csv_file.shift, csv_file.readlines) }

      context 'with CustomID' do
        let(:mapping) do
          csv_mapping(map_with_custom_id_and_custom_fields)
        end
        before do
          allow(VoterList).to receive(:read_from_s3).and_return(file.read)
          @counts = subject.import_csv
        end

        it_behaves_like 'all valid Voter uploads'

        describe "when imported Voter records have a CustomID that matches existing records associated w/ VoterList#campaign" do
          let(:csv_file_upload_with_duplicate_custom_id){ cp_tmp('voter_list_with_duplicate_custom_id_field.csv') }
          let(:dup_csv_file) do
            CSV.new(File.open(csv_file_upload_with_duplicate_custom_id).read)
          end
          let(:other_voter_list) do
            create(:voter_list, :campaign => campaign, :account => user.account)
          end

          before(:each) do
            allow(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload_with_duplicate_custom_id}").read)
            batch_import = VoterBatchImport.new(other_voter_list, valid_voters_map_with_custom_id_and_custom_fields, dup_csv_file.shift, dup_csv_file.readlines)
            result = batch_import.import_csv
            expect(result[:success]).to eq 2
            expect(result[:failed]).to eq 0
          end

          it "does not create a new Voter record" do
            expect(Voter.count).to eq(3)
          end

          it "associate updated Voter record with the new VoterList record" do
            expect(voter_list.voters.count).to eq(1)
            expect(other_voter_list.voters.count).to eq(2)
          end

          it "update any system fields on Voter record" do
            voter = Voter.find_by_custom_id("123")
            expect(voter.first_name).to eq("Foo_updated")
            expect(voter.email).to eq("foo2@bar.com")
          end

          it "update any custom voter fields on Voter record" do
            voter = Voter.find_by_custom_id("123")
            custom_voter_field_value = CustomVoterFieldValue.find_by_voter_id_and_custom_voter_field_id(voter.id, CustomVoterField.find_by_name("Gender").id)
            custom_voter_field_value.reload
            expect(custom_voter_field_value.value).to eq("Male_updated")
          end
        end
      end

      context 'without CustomID' do
        let(:mapping) do
          csv_mapping(map_without_custom_id)
        end
        before do
          allow(VoterList).to receive(:read_from_s3).and_return(file.read)
          @counts = subject.import_csv
        end

        it_behaves_like 'all valid Voter uploads'

        describe 'duplicate phone number treatment (going away w/ householding)' do
          let(:phone) do
            csv = CSV.new(File.open(csv_file_upload).read)
            csv.shift
            csv.first.split(',').first.first.gsub(/[^\d]/, '')
          end
          it 'creates a new Voter record when phone number is duplicated on same list' do
            expect(Voter.count).to eq 2
          end

          it 'creates a new Voter record when phone number is duplicated on different list for different Campaigns' do
            csv_file.rewind
            allow(VoterList).to receive(:read_from_s3).and_return(file.read)
            other_list   = create(:voter_list, :campaign => create(:power, :account => user.account))
            batch_import = VoterBatchImport.new(other_list, mapping, csv_file.shift, csv_file.readlines)
            batch_import.import_csv
            expect(Voter.count).to eq 4 # 2 voters on 2 campaigns
          end

          it 'creates a new Voter record when phone number is duplicated on different list for same Campaign' do
            csv_file.rewind
            allow(VoterList).to receive(:read_from_s3).and_return(file.read)
            other_list   = create(:voter_list, :campaign => campaign)
            batch_import = VoterBatchImport.new(other_list, mapping, csv_file.shift, csv_file.readlines)
            batch_import.import_csv
            expect(Voter.count).to eq 4 # 2 voters on 2 lists
          end
        end
      end
    end

    context 'CSV parser' do
      it 'correctly parses files with carriage return line endings' do
        require 'windozer'
        allow(AmazonS3).to receive_message_chain(:new, :read){ File.open(windoze_csv_file_upload).read }
        csv = CSV.new( Windozer.to_unix(File.open(windoze_csv_file_upload).read) )
        batch_upload = VoterBatchImport.new(voter_list, windoze_mappings, csv.shift, csv.readlines)
        actual = batch_upload.import_csv
        expect(actual[:success]).to eq(29)
        expect(actual[:failed]).to eq(0)
      end
      it "ignores columns with blank headers" do
        missing_field_file = File.open("#{fixture_path}/files/missing_field_list.csv").read
        missing_field_csv = CSV.new(missing_field_file)
        allow(VoterList).to receive(:read_from_s3).and_return(missing_field_file)
        batch_upload = VoterBatchImport.new(voter_list, valid_voters_not_available_map_without_custom_id, missing_field_csv.shift, missing_field_csv.readlines)
        result = batch_upload.import_csv
        expect(result[:success]).to eq 2
        expect(result[:failed]).to eq 0
        expect(Voter.all.count).to eq(2)
        expect(Voter.all.map(&:attributes).map(&:values).flatten).to_not include 'ignored'
      end
    end
  end
end