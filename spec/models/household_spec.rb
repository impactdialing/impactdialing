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
    let(:account){ create(:account) }
    let(:campaign){ create(:power, account: account) }
    
    before do
      households = create_list(:household, 10, campaign: campaign)
      households.each do |h|
        create(:voter, campaign: campaign, household: h)
      end
    end

    describe 'presentable(campaign)' do
      it 'returns households w/ NULL presented_at' do
        expect(Household.presentable(campaign).count).to eq campaign.households.count
      end

      it 'returns households w/ presented_at < campaign.recycle_rate.hours.ago' do
        limit              = 5
        time               = Time.now - (1.hour + 1.minute)
        households         = campaign.households.limit(limit)
        recently_presented = campaign.households.where('id NOT IN (?)', households.map(&:id))
        households.update_all(presented_at: time)
        recently_presented.update_all(presented_at: 5.minutes.ago)

        expect(Household.presentable(campaign).to_a).to eq households.to_a
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

    it 'returns true when all enabled voters have been contacted' do
      household.voters.update_all(status: CallAttempt::Status::SUCCESS)
      voter = create(:voter, {
        household: household,
        enabled: [],
        status: Voter::Status::NOTCALLED
      })
      expect(household.voters).to include(voter)
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

    it 'returns false when household is complete' do
      allow(subject).to receive(:complete?){ true }
      expect(subject.cache?).to be_falsey
    end
  end

  describe '#call_back_regardless_of_status?' do
    let(:voter){ create(:voter) }
    let(:household){ voter.household }

    context 'campaign is set to call back after voicemail delivery' do
      before do
        household.campaign.update_attributes!({
          use_recordings:                     true,
          caller_can_drop_message_manually:   true,
          call_back_after_voicemail_delivery: true
        })
      end
      it 'returns true when voicemail was delivered' do
        household.update_attributes!(status: voter.status)
        create(:bare_call_attempt, :voicemail_delivered, campaign: household.campaign, household: household, voter: voter)
        expect(household.call_back_regardless_of_status?).to be_truthy
      end

      it 'returns false when no voicemail was delivered' do
        household.update_attributes!(status: voter.status)
        expect(household.call_back_regardless_of_status?).to be_falsey
      end
    end

    context 'campaign is set to not call back after voicemail delivery' do
      it 'returns false when voicemail was delivered to house' do
        household.update_attributes!(status: voter.status)
        create(:bare_call_attempt, :voicemail_delivered, campaign: household.campaign, household: household, voter: voter)
        expect(household.call_back_regardless_of_status?).to be_falsey
      end

      it 'returns false when no voicemail delivered to house' do
        household.update_attributes!(status: voter.status)
        expect(household.call_back_regardless_of_status?).to be_falsey
      end
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
# **`created_at`**    | `datetime`         |
# **`updated_at`**    | `datetime`         |
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
