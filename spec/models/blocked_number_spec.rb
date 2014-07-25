require 'spec_helper'

describe BlockedNumber, :type => :model do
  it { is_expected.to validate_presence_of(:number) }
  it { is_expected.to validate_presence_of(:account) }
  it { is_expected.to validate_numericality_of(:number)  }

  it "ensures the number is at least 10 characters" do
    expect(BlockedNumber.new(:number => '123456789')).to have(1).error_on(:number)
    expect(BlockedNumber.new(:number => '1234567890')).to have(0).errors_on(:number)
  end

  ['-', '(', ')', '+', ' '].each do |symbol|
    it "strips #{symbol} from the number" do
      blocked_number = build(:blocked_number, :number => "123#{symbol}456#{symbol}7890")
      expect(blocked_number.save).to be_truthy
      expect(blocked_number.reload.number).to eq('1234567890')
    end
  end

  it "doesn't strip alphabetic characters" do
    blocked_number = build(:blocked_number, :number => "123a456a7890")
    expect(blocked_number).not_to be_valid
    expect(blocked_number.number).to eq('123a456a7890')
  end

  it "selects system and campaign blocked numbers" do
    campaign  = create(:campaign)
    system_blocked_number = create(:blocked_number, :number => "1111111111", :campaign => nil)
    this_campaign_blocked_number = create(:blocked_number, :number => "1111111112", :campaign => campaign )
    other_campaign_blocked_number = create(:blocked_number, :number => "1111111113", :campaign => create(:campaign) )
    expect(BlockedNumber.for_campaign(campaign)).to eq([system_blocked_number, this_campaign_blocked_number])
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
#
