class Call < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  include CallTwiml
  attr_accessible :id, :call_sid, :call_status, :caller, :state, :call_attempt, :questions, :notes, :answered_by, :campaign_type, :recording_url, :recording_duration

  has_one :call_attempt
  delegate :connect_call, :to => :call_attempt
  delegate :campaign, :to=> :call_attempt
  delegate :voter, :to=> :call_attempt
  delegate :caller_session, :to=> :call_attempt
  delegate :end_caller_session, :to=> :call_attempt
  delegate :caller_session_key, :to=> :call_attempt
  delegate :enqueue_call_flow, :to=> :call_attempt


  def incoming_call
    return connected if answered_by_human_and_caller_available?
    return abandoned if answered_by_human_and_caller_not_available?
    return call_answered_by_machine if answered_by_machine?
  end

  def connected
    connect_call
    enqueue_call_flow(VoterConnectedPusherJob, [call_attempt.caller_session_id, self.id])
    connected_twiml
  end

  def abandoned
    RedisCallFlow.push_to_abandoned_call_list(self.id);
    call_attempt.redirect_caller
    abandoned_twiml
  end

  def call_answered_by_machine
    RedisCallFlow.push_to_processing_by_machine_call_hash(self.id);
    call_attempt.redirect_caller
    call_answered_by_machine_twiml
  end

  def hungup
    enqueue_call_flow(EndRunningCallJob, [call_attempt.sid])
  end

  def disconnected
    unless cached_caller_session.nil?
      RedisCallFlow.push_to_disconnected_call_list(self.id, RedisCall.recording_duration(self.id), RedisCall.recording_url(self.id), cached_caller_session.caller_id);
      enqueue_call_flow(CallerPusherJob, [cached_caller_session.id, "publish_voter_disconnected"])
      RedisStatus.set_state_changed_time(call_attempt.campaign_id, "Wrap up", cached_caller_session.id)
    end
    disconnected_twiml
  end

  def call_ended(campaign_type, params={})
    unless caller_session.nil? # can be the case for transfers
      caller_session.publish_call_ended(params)
    end
    if call_did_not_connect?
      RedisCallFlow.push_to_not_answered_call_list(self.id, redis_call_status)
    end

    if answered_by_machine?
      RedisCallFlow.push_to_end_by_machine_call_list(self.id)
      if Campaign.preview_power_campaign?(campaign_type)  && redis_call_status == 'completed'
        call_attempt.redirect_caller
      end
    end

    if Campaign.preview_power_campaign?(campaign_type)  && redis_call_status != 'completed'
      call_attempt.redirect_caller
    end

    if call_did_not_connect?
      RedisCall.delete(self.id)
    end
    call_ended_twiml
  end

  def wrapup_and_continue
    RedisCallFlow.push_to_wrapped_up_call_list(call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT);
    call_attempt.redirect_caller
    unless cached_caller_session.nil?
      RedisStatus.set_state_changed_time(call_attempt.campaign_id, "On hold", cached_caller_session.id)
    end
  end

  def wrapup_and_stop
    RedisCallFlow.push_to_wrapped_up_call_list(call_attempt.id, CallerSession::CallerType::TWILIO_CLIENT);
    end_caller_session
  end


  def answered_by_machine?
    RedisCall.answered_by(self.id) == "machine"
  end

  def answered_by_human?
    (RedisCall.answered_by(self.id).nil? || RedisCall.answered_by(self.id) == "human")
  end

  def answered_by_human_and_caller_available?
     answered_by_human?  && RedisCall.call_status(self.id) == 'in-progress' && !cached_caller_session.nil? && cached_caller_session.assigned_to_lead?
  end


  def answered_by_human_and_caller_not_available?
    answered_by_human?  && redis_call_status == 'in-progress' && (cached_caller_session.nil? || !cached_caller_session.assigned_to_lead?)
  end

  def call_did_not_connect?
    ["no-answer", "busy", "failed"].include?(redis_call_status)
  end

  def call_connected?
    !call_did_not_connect?
  end

  def redis_call_status
    RedisCall.call_status(self.id)
  end

  def cached_caller_session
    CallerSession.find_by_id_cached(call_attempt.caller_session_id)
  end

  def data_centre
    RedisCallerSession.datacentre(call_attempt.caller_session_id)
  end



end
