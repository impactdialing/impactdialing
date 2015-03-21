require 'rails_helper'

describe 'CallFlow::DialQueue::Jobs::Recycle' do
  let(:account){ create(:account) }
  let(:fake_dial_queue) do
    double('FakeDialQueue', {
      available: double('FakeAvailable', {
        presented_and_stale: []
      }),
      recycle!: {},
      dialed: {}
    })
  end
  before do
    campaigns = create_list(:campaign, 10, account: account)
    5.times do
      campaign = campaigns.sample
      attrs = {campaign: campaign}
      create(:caller_session, attrs)
      Timecop.travel(3.weeks.ago) do
        create(:caller_session, attrs)
      end
    end

    allow(CallFlow::DialQueue).to receive(:new){ fake_dial_queue }
  end

  it 'loads distinct campaign ids for all caller sessions created in the last 2 weeks' do
    expect(fake_dial_queue).to receive(:recycle!)

    CallFlow::DialQueue::Jobs::Recycle.perform
  end
end
