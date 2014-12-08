require "spec_helper"

describe VoterList, :type => :model do
  let(:valid_attrs) do
    {
      name: 'blah',
      s3path: '/somewhere/on/s3/blah.csv',
      csv_to_system_map: {'First name' => 'first_name', 'Phone' => 'phone'},
      uploaded_file_name: 'blah.csv'
    }
  end
  it 'serializes #csv_to_system_map as JSON' do
    list = VoterList.create!(valid_attrs)
    expect(list.reload.csv_to_system_map).to eq valid_attrs[:csv_to_system_map]
  end

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
    it "should enable all voters when list enabled" do
      voter_list = create(:voter_list, enabled: false)
      voter = create(:realistic_voter, :disabled, voter_list: voter_list)
      voter_list.enabled = true
      voter_list.save
      VoterListChangeJob.perform(voter_list.id, voter_list.enabled)
      expect(voter.reload.enabled).to be_truthy
    end

    it "should disable all voters when list disabled" do
      voter_list = create(:voter_list, enabled: true)
      voter = create(:realistic_voter, voter_list: voter_list)
      voter_list.enabled = false
      voter_list.save
      VoterListChangeJob.perform(voter_list.id, voter_list.enabled)
      expect(voter.reload.enabled?(:list)).to be_falsey
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
# **`households_count`**    | `integer`          |
#
# ### Indexes
#
# * `index_voter_lists_on_user_id_and_name` (_unique_):
#     * **`account_id`**
#     * **`name`**
#
