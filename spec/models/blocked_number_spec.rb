require 'spec_helper'

describe BlockedNumber do
  it { should validate_presence_of(:number) }
  it { should validate_presence_of(:account) }
  it { should validate_numericality_of(:number)  }

  it "ensures the number is at least 10 characters" do
    BlockedNumber.new(:number => '123456789').should have(1).error_on(:number)
    BlockedNumber.new(:number => '1234567890').should have(0).errors_on(:number)
  end

  ['-', '(', ')', '+', ' '].each do |symbol|
    it "strips #{symbol} from the number" do
      blocked_number = build(:blocked_number, :number => "123#{symbol}456#{symbol}7890")
      blocked_number.save.should be_true
      blocked_number.reload.number.should == '1234567890'
    end
  end

  it "doesn't strip alphabetic characters" do
    blocked_number = build(:blocked_number, :number => "123a456a7890")
    blocked_number.should_not be_valid
    blocked_number.number.should == '123a456a7890'
  end

  it "selects system and campaign blocked numbers" do
    campaign  = create(:campaign)
    system_blocked_number = create(:blocked_number, :number => "1111111111", :campaign => nil)
    this_campaign_blocked_number = create(:blocked_number, :number => "1111111112", :campaign => campaign )
    other_campaign_blocked_number = create(:blocked_number, :number => "1111111113", :campaign => create(:campaign) )
    BlockedNumber.for_campaign(campaign).should == [system_blocked_number, this_campaign_blocked_number]
  end

end
