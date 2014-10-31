require "spec_helper"

# todo: move upload/parsing related tests to appropriate places eg VoterListBatchUpload
describe VoterList, :type => :model do

  it "can return all voter lists of the given ids" do
    v = 3.times.map { create(:voter_list) }
    expect(VoterList.by_ids([v.first.id, v.last.id])).to eq([v.first, v.last])
  end

  it "validates the uniqueness of name in a case insensitive manner" do
    user = create(:user)
    create(:voter_list, :name => 'same', :account => user.account)
    expect(build(:voter_list, :name => 'Same', :account => user.account)).to have(1).error_on(:name)
  end

  it "returns all the active voter list ids of a campaign" do
    campaign = create(:campaign)
    v1 = create(:voter_list, :id => 123, :campaign => campaign, :active => true, :enabled => true)
    v2 = create(:voter_list, :id => 1234, :campaign => campaign, :active => true, :enabled => true)
    v4 = create(:voter_list, :id => 123456, :campaign => campaign, :active => false, :enabled => true)
    v5 = create(:voter_list, :id => 1234567, :active => true, :enabled => true)
    expect(VoterList.active_voter_list_ids(campaign.id)).to eq([123,1234])
  end

  describe "enable and disable voter lists" do
    let(:campaign) { create(:campaign) }
    it "can disable all voter lists in the given scope" do
      create(:voter_list, :campaign => campaign, :enabled => true)
      create(:voter_list, :campaign => campaign, :enabled => true)
      create(:voter_list, :campaign => create(:campaign), :enabled => true)
      campaign.voter_lists.disable_all
      expect(campaign.voter_lists.all.map(&:enabled)).not_to include(true)
    end
    it "can enable all voter lists in the given scope" do
      create(:voter_list, :campaign => campaign, :enabled => false)
      create(:voter_list, :campaign => campaign, :enabled => false)
      create(:voter_list, :campaign => create(:campaign), :enabled => false)
      campaign.voter_lists.enable_all
      expect(campaign.voter_lists.all.map(&:enabled)).not_to include(false)
    end
  end

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

    describe "import from csv" do
      USER_MAPPINGS = CsvMapping.new({
                                         "LAST" => "last_name",
                                         "FIRSTName" => "first_name",
                                         "Phone" => "phone",
                                         "Email" => "email",
                                         "ID" => "custom_id",
                                         "Age" => "Age",
                                         "Gender" => "Gender",
                                     })
      let(:windoze_mappings) do
        CsvMapping.new({
          "FIRST" => "first_name",
          "Phone" => "phone",
          "Email" => "email"
        })
      end

      before :each do
        Voter.destroy_all
      end

      it "should be successful" do
        expect(VoterList).to receive(:read_from_s3).and_return(File.open(csv_file_upload).read)
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")
        expect(@result).to eq({
            :successCount => 2,
            :failedCount => 0,
            :dncCount => 0,
            :cellCount => 0
        })
      end

      it 'should handle windoze files' do
        allow(AmazonS3).to receive_message_chain(:new, :read){ File.open(windoze_csv_file_upload).read }
        actual = voter_list.import_leads(windoze_mappings, windoze_csv_file_upload, ",")
        expect(actual).to eq({
          successCount: 29,
          failedCount: 0,
          :dncCount => 0,
          :cellCount => 0
        })
      end

      it "should upload all columns except the Not Available one" do
        MAPPINGS = CsvMapping.new({"Phone"=>"phone", "Name"=>"", "Email"=>"email"})
        expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{fixture_path}/files/missing_field_list.csv").read)
        @result = voter_list.import_leads(MAPPINGS,"#{fixture_path}/files/missing_field_list.csv",",")
        expect(@result).to eq({
            :successCount => 2,
            :failedCount => 0,
            :dncCount => 0,
            :cellCount => 0
        })
        expect(Voter.all.count).to eq(2)
      end

      it "should treat a duplicate phone number as a new voter" do
        expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload}").read)
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")

        expect(Voter.count).to eq(2)
      end

      it "should parse it and save to the voters list table" do
        expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload}").read)
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")

        expect(Voter.count).to eq(2)
        voter = Voter.find_by_email("foo@bar.com")
        expect(voter.campaign_id).to eq(campaign.id)
        expect(voter.account_id).to eq(user.account.id)
        expect(voter.voter_list_id).to eq(voter_list.id)

          # check some values from the csv fixture
        expect(voter.phone).to eq("1234567895")
        expect(voter.first_name).to eq("Foo")
        expect(voter.custom_id).to eq("987")
        expect(voter.last_name).to eq("Bar")
        expect(voter.email).to eq("foo@bar.com")
        expect(voter.middle_name).to be_blank
        expect(voter.suffix).to be_blank
      end

      it "should ignore the same phone is repeated in another voters list for the same campaign" do
        expect(VoterList).to receive(:read_from_s3).twice.and_return(File.open("#{csv_file_upload}").read)
        @result = voter_list.import_leads(
            USER_MAPPINGS,
            csv_file_upload,
            ",")

        another_voter_list = create(:voter_list, :campaign => campaign, :account => user.account)
        expect(another_voter_list.import_leads(USER_MAPPINGS, csv_file_upload,",")).to eq({
          :successCount => 2,
          :failedCount => 0,
          :dncCount => 0,
          :cellCount => 0
        })
      end

      it "should add even if the same phone is repeated in a different campaign" do
        expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload}").read)

        another_voter_list = create(:voter_list, :campaign => create(:power, :account => user.account))
        expect(another_voter_list.import_leads(
            USER_MAPPINGS,
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
          expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload}").read)
          expect(VoterList).to receive(:read_from_s3).and_return(File.open("#{csv_file_upload_with_duplicate_custom_id}").read)
          @result = voter_list.import_leads(
              USER_MAPPINGS,
              csv_file_upload,
              ",")

          expect(@another_voter_list.import_leads(
              USER_MAPPINGS,
              csv_file_upload_with_duplicate_custom_id,
              ",")).to eq(
              {
                :successCount => 2,
                :failedCount => 0,
                :dncCount => 0,
                :cellCount => 0
              }
          )
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


  describe "dial" do
    let(:voter_list) { create(:voter_list, :campaign => create(:campaign, :calls_in_progress => true)) }

    it "dials all the voters who have not been dialed yet" do
      # todo: deprecate VoterList#dial
      voter1 = create(:voter, :voter_list => voter_list, :campaign => voter_list.campaign)
      voter2 = create(:voter, :voter_list => voter_list, :campaign => voter_list.campaign)
      expect(voter1).to receive(:dial)
      expect(voter2).to receive(:dial)
      allow(Voter).to receive_message_chain(:to_be_dialed, :find_in_batches).and_yield [ voter1, voter2 ]
      voter_list.dial
    end

    it "gives the count of remaining voters" do
      voter_list = create(:voter_list)
      create(:voter, :voter_list => voter_list, :status => CallAttempt::Status::SUCCESS)
      create(:voter, :voter_list => voter_list)
      expect(voter_list.voters_remaining).to eq(1)
    end
  end

  describe "valid file" do
     it "should consider csv file extension as valid" do
       expect(VoterList.valid_file?("abc.csv")).to be_truthy
     end

     it "should consider CSV file extension as valid" do
       expect(VoterList.valid_file?("abc.CSV")).to be_truthy
     end

     it "should consider txt file extension as valid" do
       expect(VoterList.valid_file?("abc.txt")).to be_truthy
     end

     it "should consider txt file extension as valid" do
       expect(VoterList.valid_file?("abc.txt")).to be_truthy
     end

     it "should consider null fileas invalid" do
       expect(VoterList.valid_file?(nil)).to be_falsey
     end

     it "should consider non csv txt file as invalid" do
       expect(VoterList.valid_file?("abc.psd")).to be_falsey
     end
  end

  describe "seperator from file extension" do
    it "should return , for csv file" do
      expect(VoterList.separator_from_file_extension("abc.csv")).to eq(',')
    end

    it "should return \t for txt file" do
      expect(VoterList.separator_from_file_extension("abc.txt")).to eq("\t")
    end

  end

  describe "create csv to system map" do
     it "should use voter primary attribute for mapping" do
       account = create(:account)
       expect(VoterList.create_csv_to_system_map(['Phone'], account)).to eq ({"Phone"=>"Phone"})
     end

     it "should use account custom attribute for mapping" do
       account = create(:account)
       create(:custom_voter_field, name: "test", account_id: account.id)
       expect(VoterList.create_csv_to_system_map(['test'], account)).to eq ({"test"=>"test"})
     end

     it "should use assign  new custom attribute for mapping" do
       account = create(:account)
       expect(VoterList.create_csv_to_system_map(['new test'], account)).to eq ({"new test"=>"new test"})
     end

     it "should use use primary attribute and custom field and assign new attribute" do
       account = create(:account)
       create(:custom_voter_field, name: "Region", account_id: account.id)
       create(:custom_voter_field, name: "Club", account_id: account.id)
       expect(VoterList.create_csv_to_system_map(['Phone','FirstName','Region','Club','Mobile'], account)).to eq ({"Phone"=>"Phone", "FirstName"=>"FirstName", "Region"=>"Region", "Club"=>"Club", "Mobile"=>"Mobile"})
     end
  end

  describe "voter enable callback after save" do
    it "should enable all voters when list enabled" do
      voter_list = create(:voter_list, enabled: false)
      voter = create(:voter, voter_list: voter_list, enabled: false)
      voter_list.enabled = true
      voter_list.save
      VoterListChangeJob.perform(voter_list.id, voter_list.enabled)
      expect(voter.reload.enabled).to be_truthy
    end

    it "should disable all voters when list disabled" do
      voter_list = create(:voter_list, enabled: true)
      voter = create(:voter, voter_list: voter_list, enabled: true)
      voter_list.enabled = false
      voter_list.save
      VoterListChangeJob.perform(voter_list.id, voter_list.enabled)
      expect(voter.reload.enabled).to be_falsey
    end

  end
end

# ## Schema Information
#
# Table name: `voter_lists`
#
# ### Columns
#
# Name                      | Type               | Attributes
# ------------------------- | ------------------ | ---------------------------
# **`id`**                  | `integer`          | `not null, primary key`
# **`name`**                | `string(255)`      |
# **`account_id`**          | `string(255)`      |
# **`active`**              | `boolean`          | `default(TRUE)`
# **`created_at`**          | `datetime`         |
# **`updated_at`**          | `datetime`         |
# **`campaign_id`**         | `integer`          |
# **`enabled`**             | `boolean`          | `default(TRUE)`
# **`separator`**           | `string(255)`      |
# **`headers`**             | `text`             |
# **`csv_to_system_map`**   | `text`             |
# **`s3path`**              | `text`             |
# **`uploaded_file_name`**  | `string(255)`      |
# **`voters_count`**        | `integer`          | `default(0)`
# **`skip_wireless`**       | `boolean`          | `default(TRUE)`
#
# ### Indexes
#
# * `index_voter_lists_on_user_id_and_name` (_unique_):
#     * **`account_id`**
#     * **`name`**
#
