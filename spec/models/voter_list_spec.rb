require 'rails_helper'

describe VoterList, :type => :model do
  let(:valid_attrs) do
    {
      name: 'blah',
      s3path: '/somewhere/on/s3/blah.csv',
      csv_to_system_map: {'ID' => 'custom_id', 'First Name' => 'first_name', 'Phone' => 'phone'},
      uploaded_file_name: 'blah.csv'
    }
  end
  it 'serializes #csv_to_system_map as JSON' do
    list = VoterList.create!(valid_attrs.merge(campaign: create(:preview)))
    expect(list.reload.csv_to_system_map).to eq valid_attrs[:csv_to_system_map]
  end

  describe 'csv_to_system_map restrictions' do
    let(:campaign){ create(:power) }
    let(:custom_id_mapping) do
      {
        'Phone' => 'phone',
        'ID' => 'custom_id'
      }
    end
    let(:voter_list) do
      build(:voter_list, {
        campaign: campaign,
        csv_to_system_map: custom_id_mapping
      })
    end
    shared_context 'first list mapped custom id' do
      let(:second_voter_list) do
        build(:voter_list, {
          campaign: campaign,
          csv_to_system_map: custom_id_mapping
        })
      end
      let(:third_voter_list) do
        build(:voter_list, {
          campaign: campaign,
          csv_to_system_map: {
            'Phone' => 'phone'
          }
        })
      end
      before do
        voter_list.save!
      end
    end
    shared_context 'first list did not map custom id' do
      let(:second_voter_list) do
        build(:voter_list, {
          campaign: campaign,
          csv_to_system_map: custom_id_mapping
        })
      end
      before do
        voter_list.csv_to_system_map = {
          'ID' => 'custom_id',
          'Phone' => 'phone'
        }
        voter_list.save!
      end
    end
    shared_examples 'any voter list requiring a phone mapping' do
      let(:csv_mapping) do
        instance_double('CsvMapping', {
          valid?: true
        })
      end
      before do
        expect(CsvMapping).to receive(:new).with(voter_list.csv_to_system_map){ csv_mapping }
      end
      it 'tells CsvMapping to validate' do
        expect(csv_mapping).to receive(:valid?)
        voter_list.valid?
      end
      it 'adds any CsvMapping#errors to :csv_to_system_map' do
        allow(csv_mapping).to receive(:valid?){ false }
        expect(csv_mapping).to receive(:errors){ ['oopsy'] }
        voter_list.valid?
        expect(voter_list.errors[:csv_to_system_map]).to eq ['oopsy']
      end
    end

    context 'when purpose == "import"' do
      it_behaves_like 'any voter list requiring a phone mapping'

      context 'when this is the first list for the campaign' do
        it 'can map custom_id' do
          expect(voter_list).to be_valid
        end
      end
      context 'when first list for campaign maps custom id' do
        include_context 'first list mapped custom id'
        it 'can map custom_id' do
          expect(second_voter_list).to be_valid
        end
        it 'is invalid if no custom id is mapped' do
          third_voter_list.valid?
          expect(third_voter_list.errors[:csv_to_system_map]).to include I18n.t('activerecord.errors.models.voter_list.custom_id_map_required')
        end
      end
      # fixme now IDs are always required, so this test and associated code should die
      # context 'when first list for campaign did not map custom id' do
      #   include_context 'first list did not map custom id'
      #   it 'cannot map custom_id' do
      #     second_voter_list.valid?
      #     expect(second_voter_list.errors[:csv_to_system_map]).to include I18n.t('activerecord.errors.models.voter_list.custom_id_map_prohibited')
      #   end
      # end
    end

    context 'when purpose == "prune_numbers"' do
      let(:purpose){ 'prune_numbers' }

      it_behaves_like 'any voter list requiring a phone mapping'

      context 'the first list mapped custom id' do
        before do
          third_voter_list.purpose = purpose
        end
        include_context 'first list mapped custom id'
        it 'mapped custom id is ignored' do
          expect(third_voter_list).to be_valid
        end
      end

      context 'the first list did not map custom id' do
        include_context 'first list did not map custom id'
        before do
          second_voter_list.purpose = purpose
        end
        it 'unmapped custom id is ignored' do
          expect(second_voter_list).to be_valid
        end
      end
    end

    context 'when purpose == "prune_leads"' do
      let(:purpose){ 'prune_leads' }

      it 'does not tell CsvMapping to validate' do
        voter_list.purpose = purpose
        csv_mapping = instance_double('CsvMapping')
        expect(csv_mapping).to_not receive(:valid?)
        allow(CsvMapping).to receive(:new){ csv_mapping }
        voter_list.valid?
      end

      context 'the first list mapped custom id' do
        before do
          second_voter_list.purpose = purpose
        end
        include_context 'first list mapped custom id'
        it 'lists with mapped custom id can prune leads' do
          expect(second_voter_list).to be_valid
        end
        it 'lists without mapped custom id cannot prune leads' do
          expect(third_voter_list).to be_invalid
        end
      end

      context 'the first list did not map custom id' do
        include_context 'first list did not map custom id'
        before do
          second_voter_list.csv_to_system_map = {
            'Phone' => 'phone'
          }
          second_voter_list.purpose = purpose
        end
        it 'no lists can prune leads' do
          expect(second_voter_list).to be_invalid
        end
      end
    end
  end

  it "validates the uniqueness of name in a case insensitive manner" do
    user = create(:user)
    create(:voter_list, :name => 'same', :account => user.account)
    expect(build(:voter_list, :name => 'Same', :account => user.account)).to have(1).error_on(:name)
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

  describe "voter enable callback after save" do
    it "should queue job to enable all members when list enabled" do
      voter_list         = create(:voter_list, enabled: false)
      voter          = create(:voter, :disabled, voter_list: voter_list)
      voter_list.enabled = true
      voter_list.save
      voter_list_change_job = {'class' => 'CallList::Jobs::ToggleActive', 'args' => [voter_list.id]}
      expect(resque_jobs(:import)).to include voter_list_change_job
    end

    it "should queue job to disable all members when list disabled" do
      voter_list         = create(:voter_list, enabled: true)
      voter              = create(:voter, :disabled, voter_list: voter_list)
      voter_list.enabled = false
      voter_list.save
      voter_list_change_job = {'class' => 'CallList::Jobs::ToggleActive', 'args' => [voter_list.id]}
      expect(resque_jobs(:import)).to include voter_list_change_job
    end
  end

  describe 'save custom fields after create callback' do
    let(:account){ create(:account) }
    let(:valid_attrs) do
      {
        campaign: create(:campaign, account: account),
        account: account,
        name: 'lotofleads.csv',
        s3path: 'impactdialing.test/lotofleads.csv',
        uploaded_file_name: 'lotofleads.csv',
        csv_to_system_map: {
          'Phone' => 'phone',
          'FirstName' => 'first_name',
          'LastName' => 'last_name',
          'STATE' => 'state',
          'POLLINGADDRESS' => 'Polling Address',
          'PARTY' => 'Party'
        }
      }
    end
    let(:contact_fields_options) do
      subject.contact_fields_options.all
    end
    subject{ VoterList.create(valid_attrs) }

    it 'saves all fields from #csv_to_system_map that are not Voter columns'
    #do
    #  expect(contact_fields_options).to match_array ['Polling Address', 'Party']
    #end
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
# **`account_id`**          | `integer`          |
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
# **`households_count`**    | `integer`          |
# **`purpose`**             | `string(255)`      | `default("import")`
#
# ### Indexes
#
# * `index_voter_lists_on_user_id_and_name` (_unique_):
#     * **`account_id`**
#     * **`name`**
#
