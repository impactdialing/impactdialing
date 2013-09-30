require 'spec_helper'
require 'reports'

def create_calls(campaigns_or_callers, attrs={})
  obj = campaigns_or_callers.sample
  if obj.kind_of? Campaign
    opts = {campaign: obj}
  else
    opts = {caller: obj}
  end
  webui_caller_sessions = []
  webui_caller_sessions << create(:webui_caller_session, {
    tDuration: 10
  }.merge(opts))
  webui_caller_sessions << create(:webui_caller_session, {
    tDuration: 20
  }.merge(opts))
  webui_caller_sessions << create(:webui_caller_session, {
    tDuration: 30,
    caller_type: 'Phone'
  }.merge(opts))
  create(:phones_only_caller_session, {
    tDuration: 10
  }.merge(opts))
  create(:phones_only_caller_session, {
    tDuration: 20
  }.merge(opts))
  create_list(:call_attempt, 10, {
    tDuration: 1
  }.merge(opts))
  create_list(:call_attempt, 20, {
    tDuration: 1
  }.merge(opts))
  if obj.kind_of? Caller
    opts = {caller_session: webui_caller_sessions.sample}
  end
  create_list(:transfer_attempt, 10, {
    tDuration: 1
  }.merge(opts))
  create_list(:transfer_attempt, 20, {
    tDuration: 1
  }.merge(opts))
  obj
end

describe 'Reports::BillableMinutes' do
  let(:power_campaign){ create(:power) }
  let(:preview_campaign){ create(:preview) }
  let(:from) do
    "#{power_campaign.created_at.year}-#{power_campaign.created_at.month}-#{power_campaign.created_at.day - 1}"
  end
  let(:to) do
    "#{power_campaign.created_at.year}-#{power_campaign.created_at.month}-#{power_campaign.created_at.day + 1}"
  end
  let(:billable_minutes){ Reports::BillableMinutes.new(from, to) }

  describe '#calculate_total(counts)' do
    let(:counts){ [30, 10, 20] }
    it 'returns the total sum of all counts in the counts array' do
      expected = counts.inject(0){ |s,n| s + n.to_i }
      actual = billable_minutes.calculate_total(counts)
      actual.should eq expected
    end
  end

  describe '#calculate_group_total(grouped)' do
    let(:grouped) do
      a = []
      5.times{ a << {'group 1' => 3} }
      5.times{ a << {'group 2' => 5} }
      a
    end
    it 'returns the total sum of each group in the grouped hash' do
      expected = {
        'group 1' => 5 * 3,
        'group 2' => 5 * 5
      }
      actual = billable_minutes.calculate_group_total(grouped)
      actual.should eq expected
    end
  end

  describe '#relation(type)' do
    it 'returns the relation of type' do
      types = [:caller_sessions, :call_attempts, :transfer_attempts]
      3.times do |i|
        expected = billable_minutes.send(:relations)[i]
        actual = billable_minutes.relation(types[i])
        actual.should eq expected
      end
    end
  end
end
