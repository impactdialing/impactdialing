require 'rails_helper'

RSpec.describe Household, :type => :model do
  subject{ build(:household) }

  describe 'associations' do
    it 'campaign is required' do
      subject.campaign = nil
      expect(subject).to have(1).error_on(:campaign)
    end
    it 'account is required' do
      subject.account = nil
      expect(subject).to have(1).error_on(:account)
    end
  end

  describe '#phone' do
    it 'is required' do
      subject.phone = nil
      expect(subject).to have_at_least(1).error_on(:phone)
    end
    it 'is 10-16 digits long' do
      subject.phone = '123456789'
      expect(subject).to have_at_least(1).error_on(:phone)

      subject.phone += '01234567890'
      expect(subject).to have_at_least(1).error_on(:phone)
    end
    it 'is unique for given campaign' do
      create(:household, phone: subject.phone, campaign_id: subject.campaign_id)
      expect(subject).to have_at_least(1).error_on(:phone)
    end
    it 'before validating: sanitizes phone of all non-digit characters' do
      str = '+1234567890pk'
      subject.phone = str
      subject.valid?
      expect(subject.phone).to eq str.gsub(/[^\d]/,'')
    end
  end

  describe 'in_dnc?' do
    let(:dnc_household){ build(:household, :dnc) }
    let(:cell_household){ build(:household, :cell) }

    it 'returns true when #blocked has :dnc bit set' do
      expect( dnc_household.in_dnc? ).to be_truthy
    end

    it 'returns true when #blocked has :cell bit set' do
      expect( cell_household.in_dnc? ).to be_truthy
    end

    it 'returns false when #blocked does not have :dnc OR :cell bit set' do
      expect( subject.in_dnc? ).to be_falsey
    end
  end

  # describe '#skip' do
  #   let(:voter) do
  #     create(:realistic_voter)
  #   end

  #   before do
  #     Timecop.freeze
  #     voter.skip
  #   end

  #   after do
  #     Timecop.return
  #   end

  #   it 'sets status to "skipped"' do
  #     expect(voter.status).to eq "skipped"
  #   end
  # end
end

# ## Schema Information
#
# Table name: `households`
#
# ### Columns
#
# Name                        | Type               | Attributes
# --------------------------- | ------------------ | ---------------------------
# **`id`**                    | `integer`          | `not null, primary key`
# **`account_id`**            | `integer`          | `not null`
# **`campaign_id`**           | `integer`          | `not null`
# **`last_call_attempt_id`**  | `integer`          |
# **`phone`**                 | `string(255)`      | `not null`
# **`blocked`**               | `integer`          | `default(0), not null`
# **`status`**                | `string(255)`      | `default("not called"), not null`
# **`presented_at`**          | `datetime`         |
# **`created_at`**            | `datetime`         | `not null`
# **`updated_at`**            | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_households_on_account_id`:
#     * **`account_id`**
# * `index_households_on_account_id_and_campaign_id_and_phone` (_unique_):
#     * **`account_id`**
#     * **`campaign_id`**
#     * **`phone`**
# * `index_households_on_blocked`:
#     * **`blocked`**
# * `index_households_on_campaign_id`:
#     * **`campaign_id`**
# * `index_households_on_last_call_attempt_id`:
#     * **`last_call_attempt_id`**
# * `index_households_on_phone`:
#     * **`phone`**
# * `index_households_on_presented_at`:
#     * **`presented_at`**
# * `index_households_on_status`:
#     * **`status`**
#
