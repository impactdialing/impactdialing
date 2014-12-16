require 'spec_helper'

describe BlockedNumber, :type => :model do
  it { is_expected.to validate_presence_of(:number) }
  it { is_expected.to validate_presence_of(:account) }
  it { is_expected.to validate_numericality_of(:number)  }
  
  let(:account){ create(:account) }
  let(:campaign){ create(:power, account: account) }

  before do
    Redis.new.flushall
  end

  describe 'load entries for a given account or campaign and number' do
    let(:other_account){ create(:account) }
    before do
      create_list(:bare_blocked_number, 10, account: account)
      create_list(:bare_blocked_number, 10, account: account, campaign: campaign)
      create_list(:bare_blocked_number, 10, account: other_account)
      @account_wide_n = BlockedNumber.where(account_id: account).where('campaign_id is null').first
      @campaign_wide_n = BlockedNumber.where(account_id: account).where(campaign_id: campaign.id).first
    end

    it 'loads account-wide numbers' do
      actual = BlockedNumber.matching(campaign, @account_wide_n.number).first

      expect(actual.id).to eq @account_wide_n.id
    end

    it 'loads campaign-wide numbers' do
      actual = BlockedNumber.matching(campaign, @campaign_wide_n.number).first

      expect(actual.id).to eq @campaign_wide_n.id
    end
  end

  describe '(un)blocking Voters with a `phone` matching `BlockedNumber#number`' do
    let!(:blocked_number){ BlockedNumber.create(account: account, campaign: campaign, number: '1234567890') }

    it 'queues DoNotCall::Jobs::BlockedNumberCreated after a BlockedNumber record is created' do
      actual = Resque.peek :background_worker
      expect(actual).to eq({'class' => 'DoNotCall::Jobs::BlockedNumberCreated', 'args' => [blocked_number.id]})
    end

    it 'queues DoNotCall::Jobs::BlockedNumberDestroyed after a BlockedNumber record is destroyed' do
      blocked_number.destroy
      actual = Resque.peek :background_worker, 0, 10
      expect(actual).to include({'class' => 'DoNotCall::Jobs::BlockedNumberDestroyed', 'args' => [account.id, campaign.id, blocked_number.number]})
    end
  end

  it "ensures the number is at least 10 characters" do
    expect(BlockedNumber.new(:number => '123456789')).to have(1).error_on(:number)
    expect(BlockedNumber.new(:number => '1234567890')).to have(0).errors_on(:number)
  end

  it 'ensures number is no more than 16 characters (reasonable max since no numbering plans currently support >15 digits)' do
    a = []
    17.times{ a << rand(9)}
    expect(BlockedNumber.new(number: a.join)).to have(1).error_on(:number)
  end

  ['-', '(', ')', '+', ' '].each do |symbol|
    it "strips #{symbol} from the number" do
      blocked_number = build(:blocked_number, :number => "123#{symbol}456#{symbol}7890")
      expect(blocked_number.save).to be_truthy
      expect(blocked_number.reload.number).to eq('1234567890')
    end
  end

  it "selects system and campaign blocked numbers" do
    campaign  = create(:campaign)
    system_blocked_number = create(:blocked_number, :number => "1111111111", :campaign => nil)
    this_campaign_blocked_number = create(:blocked_number, :number => "1111111112", :campaign => campaign )
    other_campaign_blocked_number = create(:blocked_number, :number => "1111111113", :campaign => create(:campaign) )
    expect(BlockedNumber.for_campaign(campaign)).to eq([system_blocked_number, this_campaign_blocked_number])
  end

  describe 'enforcing uniqueness' do
    let(:account_number){ '1111111111' }
    let(:campaign_number){ '1111111112' }
    let(:account){ create(:account) }
    let(:campaign){ create(:power, account: account) }
    let(:other_campaign){ create(:power, account: account) }
    let!(:account_blocked_number){ create(:blocked_number, number: account_number, account: account) }
    let!(:campaign_blocked_number){ create(:blocked_number, number: campaign_number, account: account, campaign: campaign) }

    it 'ensures uniqueness of account-wide numbers' do
      expect(BlockedNumber.new(number: account_number, account: account)).to have(1).error_on(:number)
    end

    it 'ensures uniqueness of campaign-wide numbers' do
      expect(BlockedNumber.new(number: campaign_number, account: account, campaign: campaign))
    end

    it 'allows multiple campaign-wide DNCs to have same number' do
      expect(BlockedNumber.new(number: campaign_number, account: account, campaign: other_campaign)).to have(0).errors_on(:number)
    end
  end
end

# ## Schema Information
#
# Table name: `blocked_numbers`
#
# ### Columns
#
# Name               | Type               | Attributes
# ------------------ | ------------------ | ---------------------------
# **`id`**           | `integer`          | `not null, primary key`
# **`number`**       | `string(255)`      |
# **`account_id`**   | `integer`          |
# **`created_at`**   | `datetime`         |
# **`updated_at`**   | `datetime`         |
# **`campaign_id`**  | `integer`          |
#
# ### Indexes
#
# * `index_blocked_numbers_account_id_campaign_id`:
#     * **`account_id`**
#     * **`campaign_id`**
# * `index_on_blocked_numbers_number`:
#     * **`number`**
#
