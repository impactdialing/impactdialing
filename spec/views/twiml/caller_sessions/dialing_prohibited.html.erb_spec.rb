require 'rails_helper'

describe 'twiml/caller_sessions/dialing_prohibited.xml' do
  context '@reason = :calling_is_disabled' do
    it 'Says: calling is disabled' do
      assign(:reason, :calling_is_disabled)
      render template: 'twiml/caller_sessions/dialing_prohibited.xml.erb'
      expect(rendered).to match I18n.t('twiml.dialing_prohibited.calling_is_disabled')
    end
  end

  context '@reason = :account_has_no_funds' do
    it 'Says: account has no funds' do
      assign(:reason, :account_has_no_funds)
      render template: 'twiml/caller_sessions/dialing_prohibited.xml.erb'
      expect(rendered).to match I18n.t('twiml.dialing_prohibited.account_has_no_funds')
    end
  end

  context '@reason = :time_period_exceeded' do
    it 'Says: time period exceeded' do
      assign(:reason, :time_period_exceeded)
      render template: 'twiml/caller_sessions/dialing_prohibited.xml.erb'
      expect(rendered).to match I18n.t('twiml.dialing_prohibited.time_period_exceeded')
    end
  end

  context '@reason = :subscription_limit' do
    it 'Says: no caller seats available' do
      assign(:reason, :subscription_limit)
      render template: 'twiml/caller_sessions/dialing_prohibited.xml.erb'
      expect(rendered).to match I18n.t('twiml.dialing_prohibited.subscription_limit')
    end
  end
end
