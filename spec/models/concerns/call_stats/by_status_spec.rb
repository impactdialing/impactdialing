require 'rails_helper'

describe CallStats::ByStatus do
  include FakeCallData

  before do
    @admin= create(:user)
    @account= admin.account
    @campaign= create_campaign_with_script(:bare_preview, account).last
    @voters= add_voters(campaign, :voter, 5)
    @callers= add_callers(campaign, 1)
  end

  let(:admin){ @admin }
  let(:account){ @account }
  let(:campaign){ @campaign }

  it 'calculates the FCC abaondoned rate' do
    @voters.each do |voter|
      attach_call_attempt(:abandoned_call_attempt, voter, @callers.first)
      attach_call_attempt(:completed_call_attempt, voter, @callers.first)
      attach_call_attempt(:failed_call_attempt, voter, @callers.first)
    end
    options = {scoped_to: :call_attempts, from_date: Time.now.beginning_of_day, to_date: Time.now.end_of_day}
    callStats = CallStats::ByStatus.new(@campaign, options)
    expect(callStats.fcc_abandon_rate).to eq(0.5)
  end

  it 'calculates the FCC abaondoned rate when dividing by zero' do
    options = {scoped_to: :call_attempts, from_date: Time.now.beginning_of_day, to_date: Time.now.end_of_day}
    callStats = CallStats::ByStatus.new(@campaign, options)
    expect(callStats.fcc_abandon_rate).to eq(0)
  end

  it 'calculates the FCC abaondoned rate' do
    attach_call_attempt(:abandoned_call_attempt, @voters[0], @callers.first)
    attach_call_attempt(:completed_call_attempt, @voters[1], @callers.first)
    attach_call_attempt(:failed_call_attempt, @voters[2], @callers.first)

    options = {scoped_to: :all_voters, from_date: Time.now.beginning_of_day, to_date: Time.now.end_of_day}
    callStats = CallStats::ByStatus.new(@campaign, options)
    expect(callStats.fcc_abandon_rate).to eq(0.5)
  end
end
