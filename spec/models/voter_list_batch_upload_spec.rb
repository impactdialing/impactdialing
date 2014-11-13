require 'spec_helper'

describe 'VoterListBatchUpload' do  
  describe "upload voters list" do
    let(:csv_file_upload) {
      source_file = "#{fixture_path}/files/valid_voters_list.csv"
      temp_dir = "#{fixture_path}/test_tmp"
      temp_filename = "#{temp_dir}/valid_voters_list.csv"
      FileUtils.cp source_file, temp_filename
      temp_filename
    }
    let(:windoze_csv_file_upload) do
      source_file = "#{fixture_path}/files/windoze_voters_list.csv"
      temp_dir = "#{fixture_path}/test_tmp"
      temp_filename = "#{temp_dir}/windoze_voters_list.csv"
      FileUtils.cp source_file, temp_filename
      temp_filename
    end
    let(:user) { create(:user) }
    let(:campaign) { create(:preview, :account => user.account) }
    let(:voter_list) { create(:voter_list, :campaign => campaign, :account => user.account) }
    let(:csv_to_system_map) do
      CsvMapping.new(JSON.load(@voter_list.csv_to_system_map))
    end
    let(:custom_fields) do
      {
        "Age" => "Age",
        "Gender" => "Gender"
      }
    end
    let(:map_without_custom_id) do
      {
        "LAST" => "last_name",
        "FIRSTName" => "first_name",
        "Phone" => "phone",
        "Email" => "email"
      }
    end
    let(:map_with_custom_id) do
      map_without_custom_id.merge({
        "ID" => "custom_id"
      })
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

    describe "viable CSV file" do
      before :each do
        Voter.destroy_all
      end

      context 'with CustomID' do
        it 'creates 1 Voter record associated with the appropriate Account, Campaign & VoterList for each valid CSV row' do
          file         = File.open(csv_file_upload)
          allow(VoterList).to receive(:read_from_s3).and_return(file.read)
          batch_upload = VoterListBatchUpload.new(voter_list, valid_voters_map_with_custom_id, csv_file_upload, ',')
          batch_upload.import_leads
          CSV.foreach(csv_file_upload, headers: true, return_headers: false) do |row|
            phone, first_name, last_name, middle_name, suffix, email, id, age, gender = *row
            voter = Voter.find_by_email(email)
            expect(voter).to_not be_nil
            expect(voter.account_id).to eq campaign.account_id
            expect(voter.campaign_id).to eq campaign.id
            expect(voter.voter_list_id).to eq voter_list.id
          end
        end

        it 'each created Voter record has attributes matching corresponding CSV row' do
          file         = File.open(csv_file_upload)
          allow(VoterList).to receive(:read_from_s3).and_return(file.read)
          batch_upload = VoterListBatchUpload.new(voter_list, valid_voters_map_with_custom_id, csv_file_upload, ',')
          batch_upload.import_leads
          CSV.foreach(csv_file_upload, headers: true, return_headers: false) do |row|
            phone, first_name, last_name, middle_name, suffix, email, id, age, gender = *row.map(&:last).flatten
            voter = Voter.find_by_email(email)

            expect(voter.phone).to eq phone.gsub(/[^\d]/, '')
            expect(voter.first_name).to eq first_name
            expect(voter.last_name).to eq last_name
          end
        end
      end

      # it "creates Voter records from an uploaded CSV file" do
      #   batch_upload = VoterListBatchUpload.new(voter_list, valid_voters_map_with_custom_id, csv_file_upload, ',')
      #   expect(VoterList).to receive(:read_from_s3).and_return(File.open(csv_file_upload).read)
      #   result = batch_upload.import_leads
      #   expect(result).to eq({
      #     :successCount => 2,
      #     :failedCount => 0,
      #     :dncCount => 0,
      #     :cellCount => 0
      #   })
      # end

      it 'should handle windoze files' do
        allow(AmazonS3).to receive_message_chain(:new, :read){ File.open(windoze_csv_file_upload).read }
        batch_upload = VoterListBatchUpload.new(voter_list, windoze_mappings, windoze_csv_file_upload, ",")
        actual = batch_upload.import_leads
        expect(actual).to eq({
          successCount: 29,
          failedCount: 0,
          :dncCount => 0,
          :cellCount => 0
        })
      end

      it "should upload all columns except the Not Available one" do
        allow(VoterList).to receive(:read_from_s3).and_return(File.open("#{fixture_path}/files/missing_field_list.csv").read)
        batch_upload = VoterListBatchUpload.new(voter_list, valid_voters_not_available_map_without_custom_id, "#{fixture_path}/files/missing_field_list.csv",",")
        result = batch_upload.import_leads
        expect(result).to eq({
            :successCount => 2,
            :failedCount => 0,
            :dncCount => 0,
            :cellCount => 0
        })
        expect(Voter.all.count).to eq(2)
      end

      it "should treat a duplicate phone number within the same list as a new voter" do
        allow(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload}").read)
        batch_upload = VoterListBatchUpload.new(voter_list, valid_voters_map_with_custom_id, csv_file_upload, ",")
        result = batch_upload.import_leads

        expect(Voter.count).to eq(2)
      end

      it "should parse it and save to the voters list table" do
        allow(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload}").read)
        batch_upload = VoterListBatchUpload.new(voter_list, valid_voters_map_with_custom_id, csv_file_upload, ",")

        batch_upload.import_leads

        expect(Voter.count).to eq(2)
        voter = Voter.find_by_email("foo@bar.com")
        expect(voter.campaign_id).to eq(campaign.id)
        expect(voter.account_id).to eq(user.account.id)
        expect(voter.voter_list_id).to eq(voter_list.id)

        expect(voter.phone).to eq("1234567895")
        expect(voter.first_name).to eq("Foo")
        expect(voter.custom_id).to eq("987")
        expect(voter.last_name).to eq("Bar")
        expect(voter.email).to eq("foo@bar.com")
        expect(voter.middle_name).to be_blank
        expect(voter.suffix).to be_blank
      end

      it "creates Voter records when the same phone is repeated in another voters list for the same campaign" do
        allow(VoterList).to receive(:read_from_s3).twice.and_return(File.open("#{csv_file_upload}").read)
        batch_upload = VoterListBatchUpload.new(voter_list, valid_voters_map_with_custom_id, csv_file_upload, ",")
        batch_upload.import_leads

        another_voter_list = create(:voter_list, :campaign => campaign, :account => user.account)
        expect(another_voter_list.import_leads(valid_voters_map_with_custom_id, csv_file_upload,",")).to eq({
          :successCount => 2,
          :failedCount => 0,
          :dncCount => 0,
          :cellCount => 0
        })
      end

      it "creates Voter records when the same phone is repeated in a different campaign" do
        expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload}").read)

        another_voter_list = create(:voter_list, :campaign => create(:power, :account => user.account))
        expect(another_voter_list.import_leads(
            valid_voters_map_with_custom_id,
            csv_file_upload,
            ",")).to eq(
            {
              :successCount => 2,
              :failedCount => 0,
              :dncCount => 0,
              :cellCount => 0
            }
        )
      end

      describe "If another voter uploaded with same CustoomID, it update older voter" do
        let(:csv_file_upload_with_duplicate_custom_id) {
          source_file = "#{fixture_path}/files/voter_list_with_duplicate_custom_id_field.csv"
          temp_dir = "#{fixture_path}/test_tmp"
          temp_filename = "#{temp_dir}/voter_list_with_duplicate_custom_id_field.csv"
          FileUtils.cp source_file, temp_filename
          temp_filename
        }

        before(:each) do
          @another_voter_list = create(:voter_list, :campaign => campaign, :account => user.account)
          allow(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload}").read)
          batch_upload = VoterListBatchUpload.new(voter_list, valid_voters_map_with_custom_id_and_custom_fields, csv_file_upload, ",")
          batch_upload.import_leads
          
          allow(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload_with_duplicate_custom_id}").read)
          another_batch_upload = VoterListBatchUpload.new(@another_voter_list, valid_voters_map_with_custom_id_and_custom_fields, csv_file_upload_with_duplicate_custom_id, ",")
          actual = another_batch_upload.import_leads
          expect(actual).to eq({
            :successCount => 2,
            :failedCount => 0,
            :dncCount => 0,
            :cellCount => 0
          })
        end

        it "update the voter with same id, instead of add new voter" do
          expect(Voter.count).to eq(3)
        end

        it "add the updated voter to new voter list and remove from older list" do
          expect(voter_list.voters.count).to eq(1)
          expect(@another_voter_list.voters.count).to eq(2)
        end

        it "update the new voter fields, if there any" do
          voter = Voter.find_by_custom_id("123")
          expect(voter.first_name).to eq("Foo_updated")
          expect(voter.email).to eq("foo2@bar.com")
        end

        it "also upadate the custom voter fields" do
          voter = Voter.find_by_custom_id("123")
          custom_voter_field_value = CustomVoterFieldValue.find_by_voter_id_and_custom_voter_field_id(voter.id, CustomVoterField.find_by_name("Gender").id)
          custom_voter_field_value.reload
          expect(custom_voter_field_value.value).to eq("Male_updated")
        end
      end
    end

    describe "with custom fields" do
      let(:csv_file) {
        source_file = "#{fixture_path}/files/voters_custom_fields_list.csv"
        temp_dir = "#{fixture_path}/test_tmp"
        temp_filename = "#{temp_dir}/valid_voters_list.csv"
        FileUtils.cp source_file, temp_filename
        temp_filename
      }

      let(:mappings) { CsvMapping.new({ "Phone" => "phone", "Custom" =>"Custom"}) }

      it "creates custom fields when they do not exist" do

        expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file}").read)
        custom_field = "Custom"
        voter_list = create(:voter_list, :campaign => create(:predictive, :account => user.account), :account => user.account)
        expect(voter_list.import_leads(mappings, csv_file, ",")).to eq({
          :successCount => 2,
          :failedCount => 0,
          :dncCount => 0,
          :cellCount => 0
        })
        expect(CustomVoterField.find_by_name(custom_field)).not_to be_nil
        expect(CustomVoterField.all.size).to eq(1)
        voter_list.reload
        custom_fields = voter_list.voters.collect do |voter|
          VoterMethods.get_attribute(voter, custom_field)
        end
        expect(custom_fields.length).to eq(2)
        expect(custom_fields).to include("Foo")
        expect(custom_fields).to include("Bar")
      end

      it "should not process custom fields for a voters with an invalid phone" do
        expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{fixture_path}/files/missing_phone_with_custom_fields_list.csv").read)
        mappings = CsvMapping.new({"Phone"=>"phone", "Name"=>"", "Custom"=>"Custom"})
        @result = voter_list.import_leads(mappings,"#{fixture_path}/files/missing_phone_with_custom_fields_list.csv",",")
        expect(@result).to eq({
          :successCount => 4,
          :failedCount => 1,
          :dncCount => 0,
          :cellCount => 0
        })
      end

      it 'reports when an imported number also exists in DNC list for account or campaign' do
        BlockedNumber.create!(number: '1234555-89-5', campaign: campaign, account: campaign.account)
        BlockedNumber.create!(number: '1234444-89-5', account: campaign.account)
        expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{fixture_path}/files/missing_phone_with_custom_fields_list.csv").read)
        mappings = CsvMapping.new({"Phone"=>"phone", "Name"=>"", "Custom"=>"Custom"})
        @result = voter_list.import_leads(mappings,"#{fixture_path}/files/missing_phone_with_custom_fields_list.csv",",")
        expect(@result).to eq({
          :successCount => 2,
          :failedCount => 1,
          :dncCount => 2,
          :cellCount => 0
        })
      end
    end
  end
end