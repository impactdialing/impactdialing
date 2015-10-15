require 'rails_helper'

describe 'twiml/lead/unprocessable_fallback_url.html.erb' do
  it 'hangs up' do
    render template: 'twiml/lead/unprocessable_fallback_url.html.erb'
    expect(rendered).to hangup
  end
end
