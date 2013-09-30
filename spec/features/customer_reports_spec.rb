require 'spec_helper'

describe 'Customer Reports' do
  def caller_session_attrs(caller)
    {
      caller: caller,
      campaign: caller.try(:campaign),
      tDuration: 90,
      created_at: Time.now - 2.days,
      caller_type: CallerSession::CallerType::PHONE
    }
  end
  def call_attempt_attrs(caller)
    {
      caller: caller,
      caller_session: caller.try(:caller_sessions).try(:last),
      campaign: caller.try(:campaign),
      tDuration: 30,
      created_at: Time.now - 2.days,
      status: CallAttempt::Status::ALL.sample
    }
  end
  def transfer_attempt_attrs(caller=nil)
    {
      caller_session: caller.try(:caller_sessions).try(:last),
      campaign: caller.try(:campaign),
      tDuration: 45,
      created_at: Time.now - 2.days
    }
  end
  let(:account) do
    create(:account, {
      created_at: Time.now - 7.days
    })
  end
  let(:other_account) do
    create(:account, {
      created_at: Time.now - 7.days
    })
  end
  let(:user) do
    create(:user, {account: account})
  end
  let(:other_user) do
    create(:user, {account: other_account})
  end
  let(:power) do
    create(:power, {
      account: account
    })
  end
  let(:other_power) do
    create(:power, {
      account: other_account
    })
  end
  let(:preview) do
    create(:preview, {
      account: account
    })
  end
  let(:powerful) do
    create(:power, {
      account: account
    })
  end
  let(:teaser) do
    create(:preview, {
      account: account
    })
  end
  let(:doer) do
    create(:caller, {
      account: other_account,
      campaign: other_power
    })
  end
  let(:trier) do
    create(:caller, {
      account: account,
      campaign: teaser
    })
  end
  let(:bringer) do
    create(:caller, {
      account: account,
      campaign: powerful
    })
  end
  let(:viewer) do
    create(:caller, {
      account: account,
      campaign: preview
    })
  end
  let(:callers) do
    [nil, doer, trier, bringer, viewer]
  end
  before do
    caller_sessions = []
    15.times do
      caller = callers[1..-1].sample
      create(:caller_session, caller_session_attrs(caller))
    end
    30.times{ create(:call_attempt, call_attempt_attrs(callers.sample)) }
    30.times{ create(:transfer_attempt, transfer_attempt_attrs(callers.sample)) }

    web_login_as(user)
  end

  describe 'By Campaign' do
    def sum_total(arr)
      arr.inject(0){ |s,n| s + (n.to_i/60.0).ceil }
    end
    def caller_total(caller)
      return 0 if caller.nil?
      cs = sum_total caller.caller_sessions.map(&:tDuration)
      ca = sum_total caller.call_attempts.map(&:tDuration)
      ta = sum_total caller.caller_sessions.map(&:transfer_attempts).flatten.map(&:tDuration)
      cs + ca + ta
    end

    before do
      within 'nav' do
        click_on 'Reports'
      end
      click_on 'Usage by campaign'
      page.should have_content 'Account usage by campaign'
    end

    it 'displays total minute usage per campaign' do
      # skip first 2 elements because nil is not a caller and doer belongs to other_account
      callers[2..-1].each do |caller|
        page.should have_content "#{caller.campaign.name} #{caller_total(caller)}"
      end
    end

    it 'does not display usage for other accounts' do
      page.should_not have_content "#{doer.campaign.name} #{caller_total(doer)}"
    end
  end
end