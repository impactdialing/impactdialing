class Twiml::LeadController < TwimlController
  before_filter :abort_lead_if_unprocessable_fallback_url

  if instrument_actions?
    instrument_action :answered, :disconnected, :completed, :play_message
  end

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
  # See twiml/lead/answered.html.erb for possible responses.
  def answered
    if process_request?
      dialed_call.answered(campaign, params)
    else
      dialed_call.abandon 
    end
  end

  ##
  # Update stats & save required data.
  # See twiml/lead/disconnected.html.erb for possible responses.
  def disconnected
    _campaign  = Campaign.find dialed_call.storage[:campaign_id]
    dialed_call.disconnected(_campaign, params)
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
  # See twiml/lead/play_message.html.erb.
  def play_message
    _campaign  = Campaign.find dialed_call.storage[:campaign_id]
    @recording = _campaign.recording
    dialed_call.manual_message_dropped(@recording)
  end
end

