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

  describe 'scopes' do
    let(:campaign){ create(:power) }
    
    before do
      create_list(:household, 10, campaign: campaign)
    end

    describe 'presentable(campaign)' do
      it 'returns households w/ NULL presented_at' do
        expect(Household.presentable(campaign).count).to eq campaign.households.count
      end

      it 'returns households w/ presented_at < campaign.recycle_rate.hours.ago' do
        limit              = 5
        time               = 1.hour.ago - 1.minute.ago
        households         = campaign.households.limit(limit)
        recently_presented = campaign.households.where('id NOT IN (?)', households.map(&:id))
        households.update_all(presented_at: time)
        recently_presented.update_all(presented_at: 5.minutes.ago)

        expect(Household.presentable(campaign).all).to eq households.all
      end
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

  describe 'failed?' do
    it 'returns false for default status' do
      expect(subject.failed?).to be_falsey
    end

    it 'returns true when status == CallAttempt::Status::FAILED' do
      subject.status = CallAttempt::Status::FAILED
      expect(subject.failed?).to be_truthy
    end

    it 'returns false when status != CallAttempt::Status::FAILED' do
      subject.status = CallAttempt::Status::BUSY
      expect(subject.failed?).to be_falsey
    end
  end

  describe 'complete?' do
    let(:campaign){ create(:power) }
    let(:voter){ create(:voter, campaign: campaign) }
    let(:household){ voter.household }
    let(:recording){ create(:recording, account: campaign.account) }

    before do
      create(:voter, campaign: campaign, household: voter.household)
    end

    it 'returns false for new households' do
      expect(household.complete?).to be_falsey
    end

    it 'returns false when at least 1 voter in a household has not been contacted' do
      voter.update_attributes!(status: CallAttempt::Status::SUCCESS)
      expect(household.complete?).to be_falsey
    end

    it 'returns true when all voters have been contacted' do
      household.voters.update_all(status: CallAttempt::Status::SUCCESS)
      expect(household.complete?).to be_truthy
    end

    context 'household has received a voicemail' do
      before do
        create(:call_attempt, campaign: campaign, household: household, status: CallAttempt::Status::VOICEMAIL, recording_id: recording.id)
      end

      it 'returns true when campaign is configured to not call back after voicemail delivery' do
        expect(household.complete?).to be_truthy
      end

      it 'returns false when campaign is configured to call back after voicemail delivery' do
        campaign.update_attributes!({
          call_back_after_voicemail_delivery: true,
          use_recordings: true,
          answering_machine_detect: true
        })
        expect(household.complete?).to be_falsey
      end
    end
  end

  describe 'cache?' do
    before do
      allow(subject).to receive(:failed?){ false }
      allow(subject).to receive(:blocked?){ false }
      allow(subject).to receive(:complete?){ false }
    end

    it 'returns true when household has not failed, is not blocked and is not complete' do
      expect(subject.cache?).to be_truthy
    end

    it 'returns false when household has failed' do
      allow(subject).to receive(:failed?){ true }
      expect(subject.cache?).to be_falsey
    end

    it 'returns false when household is blocked by admin DNC or cell scrub' do
      allow(subject).to receive(:blocked?){ true }
      expect(subject.cache?).to be_falsey
    end

    it 'returns false when household has is complete' do
      allow(subject).to receive(:complete?){ true }
      expect(subject.cache?).to be_falsey
    end
  end
end

# ## Schema Information
#
# Table name: `households`
#
# ### Columns
#
# Name                | Type               | Attributes
# ------------------- | ------------------ | ---------------------------
# **`id`**            | `integer`          | `not null, primary key`
# **`account_id`**    | `integer`          | `not null`
# **`campaign_id`**   | `integer`          | `not null`
# **`voters_count`**  | `integer`          | `default(0), not null`
# **`phone`**         | `string(255)`      | `not null`
# **`blocked`**       | `integer`          | `default(0), not null`
# **`status`**        | `string(255)`      | `default("not called"), not null`
# **`presented_at`**  | `datetime`         |
# **`created_at`**    | `datetime`         | `not null`
# **`updated_at`**    | `datetime`         | `not null`
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
# * `index_households_on_phone`:
#     * **`phone`**
# * `index_households_on_presented_at`:
#     * **`presented_at`**
# * `index_households_on_status`:
#     * **`status`**
#
