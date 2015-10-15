shared_context 'twilio fallback url requests' do
  before do
    ENV['TWILIO_PROCESS_FALLBACK_URLS'] = '1'
    params.merge!({
      ErrorUrl: 'http://test.com/blah'
    })
  end
end
shared_examples_for 'processable twilio fallback url requests' do
  include_context 'twilio fallback url requests'
  context 'params[:ErrorCode] can be retried' do
    [11200, 11205, 11210, 12400].each do |error_code|
      it "ErrorCode[#{error_code}] is processed" do
        post action, params.merge(ErrorCode: error_code)

        if defined?(processed_response_body_expectation)
          expect(response.body).to processed_response_body_expectation.call
        elsif defined?(processed_response_template)
          if processed_response_template.blank?
            expect(response.body).to be_blank
          else
            expect(response).to render_template processed_response_template
          end
        else
          raise "No processed response body or template expectation was set."
        end
      end
    end
  end
end

shared_examples_for 'unprocessable caller twilio fallback url requests' do
  include_context 'twilio fallback url requests'
  it 'speaks a "try again" message and hangs up' do
    post action, params.merge(ErrorCode: 11100)
    expect(response).to render_template 'twiml/caller_sessions/unprocessable_fallback_url'
  end
end

shared_examples_for 'unprocessable lead twilio fallback url requests' do
  include_context 'twilio fallback url requests'
  it 'hangs up' do
    post action, params.merge(ErrorCode: 11100)
    expect(response).to render_template 'twiml/lead/unprocessable_fallback_url'
  end
end
