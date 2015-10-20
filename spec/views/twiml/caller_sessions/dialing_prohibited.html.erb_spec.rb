require 'rails_helper'

describe 'twiml/caller_sessions/dialing_prohibited.html' do
  context '@reason = :calling_is_disabled' do
    it 'Says: calling is disabled' do
      assign(:reason, :calling_is_disabled)
      render template: 'twiml/caller_sessions/dialing_prohibited.html.erb'
      expect(rendered).to say(I18n.t('dialer.twiml.caller.calling_is_disabled')).and_hangup
    end
  end

  context '@reason = :account_has_no_funds' do
    it 'Says: account has no funds' do
      assign(:reason, :account_has_no_funds)
      render template: 'twiml/caller_sessions/dialing_prohibited.html.erb'
      expect(rendered).to say(I18n.t('dialer.twiml.caller.account_has_no_funds')).and_hangup
    end
  end

  context '@reason = :time_period_exceeded' do
    it 'Says: time period exceeded' do
      assign(:reason, :time_period_exceeded)
      render template: 'twiml/caller_sessions/dialing_prohibited.html.erb'
      expect(rendered).to say(I18n.t('dialer.twiml.caller.time_period_exceeded')).and_hangup
    end
  end

  context '@reason = :subscription_limit' do
    it 'Says: no caller seats available' do
      assign(:reason, :subscription_limit)
      render template: 'twiml/caller_sessions/dialing_prohibited.html.erb'
      expect(rendered).to say(I18n.t('dialer.twiml.caller.subscription_limit')).and_hangup
    end
  end
end
