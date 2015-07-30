class Twiml::LeadController < TwimlController
private
  def dialed_call
    @dialed_call ||= CallFlow::Call::Dialed.new(params[:AccountSid], params[:CallSid])
  end

  def campaign
    @campaign ||= Campaign.find params[:campaign_id]
  end

public
  def answered
    campaign.number_not_ringing
    dialed_call.answered(campaign, params)
  end

  def disconnected

  end

  def completed
  end
end

