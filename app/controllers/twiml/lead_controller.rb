class Twiml::LeadController < TwimlController
private
  def dialed_call
    @dialed_call ||= CallFlow::Call::Dialed.new(params[:AccountSid], params[:CallSid])
  end

  def answered_by_machine?
    params[:AnsweredBy] == 'machine'
  end
  def answered_by_human?
    not answered_by_machine?
  end

  def campaign
    @campaign ||= Campaign.find params[:campaign_id]
  end

  def caller_session
    @caller_session ||= if campaign.predictive? and answered_by_human?
                          caller_session_id = RedisOnHoldCaller.longest_waiting_caller(campaign.id)
                          CallerSession.find(caller_session_id)
                        else
                          CallerSession.where(sid: dialed_call.caller_session_sid).first
                        end
  end

public
  def answered
    campaign.number_not_ringing
    dialed_call.answered(campaign, caller_session, params)
  end

  def disconnected

  end

  def completed
  end
end

