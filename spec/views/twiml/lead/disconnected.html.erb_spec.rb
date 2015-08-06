require 'rails_helper'

describe 'twiml/lead/disconnected.xml.erb' do
  it 'renders Hangup twiml' do
    render template: 'twiml/lead/disconnected.xml.erb'
    expect(rendered).to hangup
  end
end

