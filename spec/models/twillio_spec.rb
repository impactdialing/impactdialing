require 'spec_helper'

describe Twillio, :type => :model do
  it "should setup_call by changing voter info " do
    campaign = create(:campaign)
    voter = create(:voter, campaign: campaign)
    caller_session = create(:caller_session, campaign: campaign)
    Twillio.setup_call(voter, caller_session, campaign)
    expect(Call.all.size).to eq(1)
  end

  it "caller sessions update in progress should be updated " do
    campaign = create(:campaign)
    voter = create(:voter, campaign: campaign)
    caller_session = create(:caller_session, campaign: campaign)
    Twillio.setup_call(voter, caller_session, campaign)
    expect(caller_session.attempt_in_progress).not_to be_nil
  end
end
