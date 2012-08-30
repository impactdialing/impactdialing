require 'spec_helper'

describe CallerGroup do
  context 'validations' do
    it {should allow_mass_assignment_of :name}
    it {should allow_mass_assignment_of :campaign_id}
    it {should validate_presence_of :name}
    it {should have_many :callers}
    it {should belong_to :campaign}
  end

  it 'updates its callers to its campaign when saved' do
    original_campaign = Factory(:campaign)
    caller_group = Factory(:caller_group, campaign: original_campaign)
    caller = Factory(:caller, caller_group: caller_group)
    new_campaign = Factory(:campaign)
    # caller_group.update_attributes(campaign_id: new_campaign.id)

    puts 'new_campaign.id:'
    p new_campaign.id
    caller_group.campaign_id = new_campaign.id
    puts 'caller_group.campaign_id from spec'
    p caller_group.campaign_id
    caller_group.save

    caller.campaign.should equal new_campaign
  end
end
