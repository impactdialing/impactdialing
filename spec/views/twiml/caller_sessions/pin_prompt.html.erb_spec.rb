require 'rails_helper'

describe 'twiml/caller_sessions/pin_prompt' do
  let(:path){ 'twiml/caller_sessions/pin_prompt' }
  it 'prompts caller for PIN' do
    assign(:current_attempt, 0)
    assign(:next_attempt, 1)
    gather_options = {
      :finishOnKey => '*',
      :timeout => 10,
      :method => "POST",
      :action => identify_caller_url({
        :host => Settings.twilio_callback_host,
        :port => Settings.twilio_callback_port,
        :protocol => "http://",
        :attempt => 1
      })
    }

    render template: path

    expect(rendered).to gather(gather_options).with_nested_say(I18n.t('dialer.twiml.caller.pin_prompt'))
  end

  it 'prompts caller for PIN on subsequent attempts' do
    assign(:current_attempt, 1)
    assign(:next_attempt, 2)

    render template: path

    expect(rendered).to include I18n.t('dialer.twiml.caller.pin_invalid')
    expect(rendered).to include I18n.t('dialer.twiml.caller.pin_prompt')
  end

  it "Hangs up on incorrect pin after the third attempt" do
    assign(:current_attempt, 3)

    render template: path

    expect(rendered).to say(I18n.t('dialer.twiml.caller.pin_invalid')).and_hangup
  end
end
