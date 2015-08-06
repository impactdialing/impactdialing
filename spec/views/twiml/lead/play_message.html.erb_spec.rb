require 'rails_helper'

describe 'twiml/lead/play_message.html.erb' do
  let(:recording){ create(:recording) }

  it 'renders twiml to play a recorded message' do
    allow(recording.file).to receive(:url){ 'oolala.jive' }
    assign(:recording, recording)
    render
    expect(rendered).to play recording.file.url
  end
end

