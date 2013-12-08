module TwilioRequestStubs
  def self.included(base)
    base.send :include, TwilioRequestHelpers
    base.send :include, TwilioResponseHelpers
  end

  def stub_twilio_new_call_request(success=true)
    @new_call_request = stub_request(:post, twilio_calls_url).
      to_return(twilio_new_call_response)
  end

  def stub_twilio_redirect_request(post_body, success=true)
    @redirect_request = stub_request(:post, twilio_call_url(call_sid)).
      with(:body => request_body(post_body)).
      to_return(twilio_updated_call_response)
  end

  def stub_twilio_kick_participant_request(success=true)
    @kick_request = stub_request(:delete, twilio_conference_kick_participant_url(conference_sid, call_sid)).
      to_return({
        :status => 204
      })
  end

  def stub_twilio_conference_list_request(success=true)
    @conference_list_request = stub_request(:get, twilio_conferences_url).
      to_return(twilio_conference_list_response)
  end

  def stub_twilio_conference_by_name_request(success=true)
    @conf_by_name_request = stub_request(:get, twilio_conference_by_name_url(conference_name)).
      to_return(twilio_conference_by_name_response(success))
  end

  def stub_twilio_mute_participant_request(success=true)
    @mute_participant_request = stub_request(:post, twilio_conference_mute_url(conference_sid, call_sid)).
      with(:body => twilio_mute_request_body).
      to_return(twilio_mute_participant_response(success))
  end

  def stub_twilio_unmute_participant_request(success=true)
    @unmute_participant_request = stub_request(:post, twilio_conference_unmute_url(conference_sid, call_sid)).
      with(:body => twilio_unmute_request_body).
      to_return(twilio_unmute_participant_response(success))
  end
end