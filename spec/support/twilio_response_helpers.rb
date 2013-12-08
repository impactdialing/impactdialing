module TwilioResponseHelpers
  def self.included(base)
    base.send :include, TwilioResponseBodies
  end

  def twilio_conference_by_name_response(success=true)
    {
      :status => 200,
      :body => conference_by_name_response_body,
      :headers => {
        'Content-Type' => 'text/xml'
      }
    }
  end

  def twilio_conference_list_response(success=true)
    {
      :status => 200,
      :body => conference_list_response_body,
      :headers => {
        'Content-Type' => 'text/xml'
      }
    }
  end

  def twilio_mute_participant_response(success=true)
    {
      :status => 200,
      :body => muted_participant_response_body,
      :headers => {}
    }
  end

  def twilio_unmute_participant_response(success=true)
    {
      :status => 200,
      :body => unmuted_participant_response_body,
      :headers => {}
    }
  end

  def twilio_updated_call_response(success=true)
    {
      :status => 200,
      :body => updated_call_response_body,
      :headers => {
        'Content-Type' => 'text/xml'
      }
    }
  end

  def twilio_new_call_response(success=true)
    {
      :status => 200,
      :body => new_call_response_body,
      :headers => {
        'Content-Type' => 'text/xml'
      }
    }
  end
end