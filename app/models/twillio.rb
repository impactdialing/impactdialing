class Twillio
  
  def self.dial(voter_info, caller_session)
    voter = Voter.find(voter_info["id"])
    campaign = caller_session.campaign
    call_attempt = setup_call(voter, caller_session, campaign)    
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)  
    RedisCaller.move_on_hold_waiting_to_connect(campaign.id, caller_session.id)      
    EM.run do
      http = twilio_lib.make_call(campaign, voter, call_attempt)
      http.callback { 
        response = JSON.parse(http.response)  
        if response["status"] == 400
          handle_failed_call(call_attempt, caller_session)
          RedisCaller.move_waiting_to_connect_on_hold(campaign.id, caller_session.id)
        else
          RedisCallAttempt.update_call_sid(call_attempt.id, response["sid"])
        end
         }
      http.errback {}            
    end    
  end
  
  def self.dial_predictive_em(iter, voter)
    call_attempt = setup_call_predictive(voter)
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)  
    Rails.logger.info "#{call_attempt.id} - before call"        
    http = twilio_lib.make_call(voter.campaign, voter, call_attempt)
    http.callback { 
      Rails.logger.info "#{call_attempt.id} - after call"    
      response = JSON.parse(http.response)  
      if response["status"] == 400
        handle_failed_call(call_attempt, nil, voter)
      else
        RedisCallAttempt.update_call_sid(call_attempt.id, response["sid"])
      end
      iter.return(http)      
       }
    http.errback { iter.return(http) }    
    
  end
  
  def self.setup_call_predictive(voter)
    attempt = voter.call_attempts.create(campaign:  voter.campaign, dialer_mode:  voter.campaign.type, status:  CallAttempt::Status::RINGING, call_start:  Time.now)
    voter.update_attributes(:last_call_attempt_id => attempt.id, :last_call_attempt_time => Time.now, status: CallAttempt::Status::RINGING)
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.load_call_attempt_info(attempt.id, attempt)
      RedisVoter.setup_call_predictive(voter.id, attempt.id)
    end
    Call.create(call_attempt: attempt, all_states: "", state: "initial")
    RedisCampaignCall.add_to_ringing(voter.campaign.id, attempt.id)
    MonitorEvent.call_ringing(voter.campaign)
    attempt
  end
  
  
  
  def self.setup_call(voter, caller_session, campaign)
    attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => caller_session, :caller => caller_session.caller, call_start:  Time.now)    
    voter.update_attributes(:last_call_attempt_id => attempt.id, :last_call_attempt_time => Time.now, :caller_session_id => caller_session.id, status: CallAttempt::Status::RINGING)
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.load_call_attempt_info(attempt.id, attempt)
      RedisVoter.setup_call(voter.id, attempt.id, caller_session.id)
      RedisCallerSession.set_attempt_in_progress(caller_session.id, attempt.id)
    end
    Call.create(call_attempt: attempt, all_states: "", state: "initial")
    RedisCampaignCall.add_to_ringing(campaign.id, attempt.id)
    MonitorEvent.call_ringing(campaign)
    attempt    
  end
  
  def handle_failed_call(attempt, caller_session, voter)
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.failed_call(attempt.id)
      RedisVoter.failed_call(voter.id)
    end
    # update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    caller_session.redirect_caller
  end
  
  
  
end