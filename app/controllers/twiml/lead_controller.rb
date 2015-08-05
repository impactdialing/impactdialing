class Twiml::LeadController < TwimlController
private
  def dialed_call
    @dialed_call ||= CallFlow::Call::Dialed.new(params[:AccountSid], params[:CallSid])
  end

  def campaign
    @campaign ||= Campaign.find params[:campaign_id]
  end

public
  ##
  # Update stats, save required data & populate flags to determine
  # which TwiML response to provide Twilio.
  # See twiml/lead/answered.xml.erb for possible responses.
  def answered
    dialed_call.answered(campaign, params)
  end

  ##
  # Update stats & save required data.
  # See twiml/lead/disconnected.xml.erb for possible responses.
  def disconnected
    dialed_call.disconnected(params)
  end

  ##
  # Update stats, save required data & redirect caller if needed.
  # Renders nothing because Twilio requests this after the call has ended.
  def completed
    dialed_call.completed(campaign, params)
    render nothing: true
  end

  ##
  # Save required data and play a recorded message to the dialed party.
  # This end-point is requested by Twilio when a Caller clicks to drop message.
  def play_message
  end
end

