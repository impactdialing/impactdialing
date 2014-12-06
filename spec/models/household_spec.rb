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

    it 'voter_list is required on create' do
      subject.voter_list = nil
      expect(subject).to have(1).error_on(:voter_list)
    end

    it 'voter_list may be nil on updates when CustomID is used' do
      subject.save!
      subject.voter_list = nil
      expect(subject).to have(0).errors_on(:voter_list)
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

  describe 'voicemail_history' do
    before do
      subject.campaign.update_attributes(recording_id: 12)
    end
    context '#update_voicemail_history' do
      let(:recording_id){ subject.campaign.recording_id.to_s }
      it 'appends the current campaign.recording_id to voicemail_history' do
        subject.update_voicemail_history
        expect(subject.voicemail_history).to eq recording_id

        subject.update_voicemail_history
        expect(subject.voicemail_history).to eq "#{recording_id},#{recording_id}"
      end
    end

    context '#yet_to_receive_voicemail?' do
      it 'returns true when voicemail_history is blank' do
        expect(subject.yet_to_receive_voicemail?).to be_truthy
      end
      it 'returns false otherwise' do
        subject.update_voicemail_history
        expect(subject.yet_to_receive_voicemail?).to be_falsey
      end
    end
  end

  describe 'in_dnc?' do
    let(:blocked_household){ build(:household, :blocked) }

    it 'returns true when Voter#enabled has :blocked bit set' do
      expect( blocked_household.in_dnc? ).to be_truthy
    end

    it 'returns false when Voter#enabled does not have :blocked bit set' do
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
# **`voter_list_id`**         | `integer`          |
# **`last_call_attempt_id`**  | `integer`          |
# **`phone`**                 | `string(255)`      | `not null`
# **`enabled`**               | `integer`          | `default(0), not null`
# **`voicemail_history`**     | `string(255)`      |
# **`status`**                | `string(255)`      | `default("not called"), not null`
# **`presented_at`**          | `datetime`         | `not null`
# **`created_at`**            | `datetime`         | `not null`
# **`updated_at`**            | `datetime`         | `not null`
#
# ### Indexes
#
# * `index_households_on_account_id`:
#     * **`account_id`**
# * `index_households_on_campaign_id`:
#     * **`campaign_id`**
# * `index_households_on_enabled`:
#     * **`enabled`**
# * `index_households_on_last_call_attempt_id`:
#     * **`last_call_attempt_id`**
# * `index_households_on_phone`:
#     * **`phone`**
# * `index_households_on_presented_at`:
#     * **`presented_at`**
# * `index_households_on_status`:
#     * **`status`**
# * `index_households_on_voter_list_id`:
#     * **`voter_list_id`**
#
