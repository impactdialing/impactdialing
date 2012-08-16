class Twillio
  
  def self.dial(voter_info, caller_session)
    voter = Voter.find(voter_info["id"])
    campaign = caller_session.campaign
    redis_connection = RedisConnection.call_flow_connection
    call_attempt = setup_call(voter, caller_session, campaign, redis_connection)    
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)        
    EM.run do
      http = twilio_lib.make_call_em(campaign, voter, call_attempt)
      http.callback { 
        response = JSON.parse(http.response)  
        if response["RestException"]
          handle_failed_call(call_attempt, caller_session, redis_connection)
        else
          RedisCallAttempt.update_call_sid(call_attempt.id, response["sid"])
        end
         }
      http.errback {}            
    end    
  end
  
  
  def self.setup_call(voter, caller_session, campaign, redis_connection)
    attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => caller_session, :caller => caller_session.caller, call_start:  Time.now)    
    redis_connection.pipelined do
      RedisCallAttempt.load_call_attempt_info(attempt.id, attempt, redis_connection)
      RedisVoter.setup_call(voter.id, attempt.id, caller_session.id, redis_connection)
      RedisCallerSession.set_attempt_in_progress(caller_session.id, attempt.id, redis_connection)
    end
    Call.create(call_attempt: attempt, all_states: "")
    attempt    
  end
  
  def handle_failed_call(attempt, caller_session, voter, redis_connection)
    redis_connection.pipelined do
      RedisCallAttempt.failed_call(attempt.id, redis_connection)
      RedisVoter.failed_call(voter.id, redis_connection)
      RedisAvailableCaller.add_caller(campaign_id, caller_session.id, redis_connection)
    end
    # update_attributes(:on_call => true, :available_for_call => true, :attempt_in_progress => nil)
    caller_session.redirect_caller
  end
  
  
  
end