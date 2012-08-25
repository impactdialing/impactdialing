class Twillio
  
  def self.dial(voter_info, caller_session)
    voter = Voter.find(voter_info["id"])
    campaign = caller_session.campaign
    call_attempt = setup_call(voter, caller_session, campaign)    
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)        
    EM.run do
      http = twilio_lib.make_call_em(campaign, voter, call_attempt)
      http.callback { 
        response = JSON.parse(http.response)  
        if response["RestException"]
          handle_failed_call(call_attempt, caller_session)
        else
          RedisCallAttempt.update_call_sid(call_attempt.id, response["sid"])
        end
         }
      http.errback {}            
    end    
  end
  
  def self.dial_predictive_em(iter, voter)
    call_attempt = setup_call_predictive(voter, self.campaign.type)
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)  
    Rails.logger.info "#{call_attempt.id} - before call"        
    http = twilio_lib.make_call(campaign, self, call_attempt)
    http.callback { 
      Rails.logger.info "#{call_attempt.id} - after call"    
      response = JSON.parse(http.response)  
      if response["RestException"]
        handle_failed_call(call_attempt, nil, voter)
      else
        RedisCallAttempt.update_call_sid(call_attempt.id, response["sid"])
      end
      iter.return(http)      
       }
    http.errback { iter.return(http) }    
    
  end
  
  def self.setup_call_predictive(voter, mode = 'robo')
    call_attempt = voter.call_attempts.create(campaign:  self.campaign, dialer_mode:  mode, status:  CallAttempt::Status::RINGING, call_start:  Time.now)
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.load_call_attempt_info(attempt.id, attempt)
      RedisVoter.setup_call(voter.id, attempt.id, nil)
    end
    Call.create(call_attempt: attempt, all_states: "")    
    call_attempt
  end
  
  
  
  def self.setup_call(voter, caller_session, campaign)
    attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => caller_session, :caller => caller_session.caller, call_start:  Time.now)    
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.load_call_attempt_info(attempt.id, attempt)
      RedisVoter.setup_call(voter.id, attempt.id, caller_session.id)
      RedisCallerSession.set_attempt_in_progress(caller_session.id, attempt.id)
    end
    Call.create(call_attempt: attempt, all_states: "")
    attempt    
  end
  
  def handle_failed_call(attempt, caller_session, voter)
    $redis_call_flow_connection.pipelined do
      RedisCallAttempt.failed_call(attempt.id)
      RedisVoter.failed_call(voter.id)
      RedisAvailableCaller.add_caller(campaign_id, caller_session.id) unless caller_session.nil?
    end
    # update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    caller_session.redirect_caller
  end
  
  
  
end