require 'rails_helper'

describe CallStats::ByStatus do
  include FakeCallData

  it 'calculates the FCC abaondoned rate' do
    admin= create(:user)
    account= admin.account
    campaign= create_campaign_with_script(:bare_preview, account).last
    voters= add_voters(campaign, :voter, 5)
    callers= add_callers(campaign, 1)
    voters.each do |voter|
      attach_call_attempt(:abandoned_call_attempt, voter, callers.first)
      attach_call_attempt(:completed_call_attempt, voter, callers.first)
      attach_call_attempt(:failed_call_attempt, voter, callers.first)
    end
    options = {scoped_to: :all_voters, from_date: 'from date', to_date: 'to date'}
    # (selective date range)
    # selective_date_range_picker
    # fcc_abandon_rate = subject.new(campaign, options)
    callStats = CallStats::ByStatus.new(campaign, options)
    expect(callStats.fcc_abandon_rate).to eq(0.5)
  end
end
