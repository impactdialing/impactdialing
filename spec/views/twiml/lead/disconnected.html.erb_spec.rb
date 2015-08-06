require 'rails_helper'

describe 'twiml/lead/disconnected.html.erb' do
  it 'renders Hangup twiml' do
    render template: 'twiml/lead/disconnected.html.erb'
    expect(rendered).to hangup
  end
end

