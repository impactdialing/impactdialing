require 'spec_helper'
require 'reports'

describe Reports::Customer::ByStatus do
  describe '#build' do
    let(:from){ 2.days.ago.beginning_of_day }
    let(:to){ 0.days.ago.end_of_day }
    let(:account){ create(:account) }
    let(:other_account){ create(:account) }
    let(:campaign) do
      create(:power, {
        account: account
      })
    end
    let(:other_campaign) do
      create(:preview, {
        account: other_account
      })
    end
    let(:billable_minutes){ Reports::BillableMinutes.new(from, to) }
    let(:by_status){ Reports::Customer::ByStatus.new(billable_minutes, account) }

    before do
      create_list(:call_attempt, 15, {
        campaign: campaign,
        status: CallAttempt::Status::VOICEMAIL,
        caller_id: nil,
        tDuration: 30,
        created_at: 1.day.ago
      })

      create_list(:call_attempt, 15, {
        campaign: campaign,
        status: CallAttempt::Status::ABANDONED,
        caller_id: nil,
        tDuration: 90,
        created_at: 1.day.ago
      })

      create_list(:call_attempt, 15, {
        campaign: campaign,
        status: CallAttempt::Status::HANGUP,
        caller_id: nil,
        tDuration: 20,
        created_at: 1.day.ago
      })

      create_list(:call_attempt, 30, {
        campaign: other_campaign,
        status: CallAttempt::Status::ABANDONED,
        caller_id: nil,
        tDuration: 90,
        created_at: 1.day.ago
      })
    end

    it 'returns a hash of counts as values and statuses as keys' do
      voicemail = 15
      abandoned = 30
      hangup = 15
      expected = {
        CallAttempt::Status::VOICEMAIL => voicemail,
        CallAttempt::Status::ABANDONED => abandoned,
        CallAttempt::Status::HANGUP => hangup
      }
      actual = by_status.build
      expect(actual).to eq expected
    end
  end
end
