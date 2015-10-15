require 'rails_helper'

describe 'twiml/caller_sessions/unprocessable_fallback_url.html.erb' do
  it 'speaks spoken text and hangs up' do
    render template: 'twiml/caller_sessions/unprocessable_fallback_url.html.erb'
    expect(rendered).to say(I18n.t('dialer.twiml.caller.unprocessable_fallback_url')).and_hangup
  end
end
