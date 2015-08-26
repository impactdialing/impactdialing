require 'rails_helper'

describe 'CallFlow::DialQueue::Jobs::Recycle' do
  subject{ CallFlow::DialQueue::Jobs::Recycle }
  let(:account){ create(:account) }
  let(:fake_dial_queue) do
    double('FakeDialQueue', {
      available: double('FakeAvailable', {
        presented_and_stale: [],
        insert: nil
      }),
      recycle!: {},
      dialed: {}
    })
  end
  let(:campaigns) do
    create_list(:campaign, 10, account: account)
  end
  let(:caller_session_campaigns){ [] }

  before do
    5.times do
      campaign = campaigns.sample
      caller_session_campaigns << campaign
      attrs = {campaign: campaign}
      create(:caller_session, attrs)
      Timecop.travel(1.weeks.ago) do
        create(:caller_session, attrs)
      end
    end
    3.times do |i|
      campaign = campaigns.select{|campaign| !caller_session_campaigns.include?(campaign) }[i]
      campaign.update_column :updated_at, 31.days.ago
    end
    allow(CallFlow::DialQueue).to receive(:new){ fake_dial_queue }
  end

  it 'loads distinct campaign ids for all caller sessions created in the last 2 weeks' do
    # 5 campaigns have recent caller sessions
    expect(fake_dial_queue).to receive(:recycle!).at_least(5).times
    subject.perform
  end

  # if recycle is received more than 7 times then duplicate campaigns were loaded
  it 'loads distinct campaign ids updated in the last 30 days that were not loaded via caller sessions' do
    # 2 campaigns have been updated in last 30 days
    expect(fake_dial_queue).to receive(:recycle!).exactly(7).times
    subject.perform
  end
end

