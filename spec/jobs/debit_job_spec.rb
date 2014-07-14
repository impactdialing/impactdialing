require 'spec_helper'

describe DebitJob do
  let(:account1){ create(:account) }
  let(:subscription1) do
    create(:business, {
      account: account1
    })
  end
  let(:account2){ create(:account) }
  let(:subscription2) do
    create(:pro, {
      account: account2
    })
  end
  let(:campaign1) do
    create(:preview, {
      account: account1
    })
  end
  let(:campaign2) do
    create(:power, {
      account: account2
    })
  end
  before do
    create_list(:caller_session, 5, {
      campaign: campaign1,
      debited: false,
      tStartTime: 20.minutes.ago,
      tEndTime: 15.minutes.ago,
      caller_type: 'Phone',
      type: 'WebuiCallerSession',
      tDuration: 5 * 60
    })
    create_list(:caller_session, 5, {
      campaign: campaign2,
      debited: false,
      tStartTime: 40.minutes.ago,
      tEndTime: 22.minutes.ago,
      caller_type: 'Phone',
      type: 'WebuiCallerSession',
      tDuration: 5 * 60
    })
    create_list(:caller_session, 4, {
      campaign: campaign1,
      debited: false,
      tStartTime: 20.minutes.ago,
      tEndTime: 10.minutes.ago,
      caller_type: 'Twilio client',
      type: 'WebuiCallerSession',
      tDuration: 10 * 60
    })
    create_list(:caller_session, 4, {
      campaign: campaign2,
      debited: false,
      tStartTime: 20.minutes.ago,
      tEndTime: 10.minutes.ago,
      caller_type: 'Twilio client',
      type: 'WebuiCallerSession',
      tDuration: 10 * 60
    })
    create_list(:call_attempt, 4, {
      campaign: campaign1,
      debited: false,
      tStartTime: 19.minutes.ago,
      tEndTime: 18.minutes.ago,
      tDuration: 35,
      status: 'Call completed with success.'
    })
    create_list(:call_attempt, 4, {
      campaign: campaign2,
      debited: false,
      tStartTime: 19.minutes.ago,
      tEndTime: 18.minutes.ago,
      tDuration: 35,
      status: 'Call completed with success.'
    })
    create_list(:transfer_attempt, 3, {
      campaign: campaign1,
      debited: false,
      tStartTime: 19.minutes.ago,
      tEndTime: 18.minutes.ago,
      tDuration: 45,
      status: 'Call completed with success.'
    })
    create_list(:transfer_attempt, 3, {
      campaign: campaign2,
      debited: false,
      tStartTime: 19.minutes.ago,
      tEndTime: 18.minutes.ago,
      tDuration: 45,
      status: 'Call completed with success.'
    })
  end

  it 'debits all subscriptions and records the debit action' do
    expect(CallAttempt.debit_pending.count).to eq 8
    DebitJob.perform
    expect(CallAttempt.where(debited: true).count).to eq 8
    expect(TransferAttempt.where(debited: true).count).to eq 6
    expect(CallerSession.where(debited: true).count).to eq 10
  end
end