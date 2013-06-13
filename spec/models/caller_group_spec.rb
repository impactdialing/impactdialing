require 'spec_helper'

describe CallerGroup do
  context 'validations' do
    it {should allow_mass_assignment_of :name}
    it {should allow_mass_assignment_of :campaign_id}
    it {should validate_presence_of :name}
    it {should have_many :callers}
    it {should belong_to :campaign}
    it {should belong_to :account}
  end

  it 'updates its callers to its campaign when saved' do
    original_campaign = Factory(:preview)
    caller = Factory(:caller, campaign_id: original_campaign.id)
    caller_group = Factory(:caller_group, campaign_id: original_campaign.id, callers: [caller])
    new_campaign = Factory(:predictive, name: "new")
    Resque.should_receive(:enqueue).with(CallerGroupJob, caller_group.id)
    caller_group.update_attributes(campaign_id: new_campaign.id)
    caller_group.campaign.should eq(new_campaign)
  end
end
