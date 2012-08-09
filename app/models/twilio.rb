class Twilio
  
  def self.dial(voter_info)
    call_attempt = setup_call(voter_info)    
    twilio_lib = TwilioLib.new(TWILIO_ACCOUNT, TWILIO_AUTH)        
    EM.run do
      http = twilio_lib.make_call_em(campaign, voter, call_attempt)
      http.callback { 
        response = JSON.parse(http.response)  
        if response["RestException"]
          handle_failed_call(call_attempt, self)
        else
          call_attempt.update_attributes(:sid => response["sid"])
        end
         }
      http.errback {}            
    end    
  end
  
  
  def self.setup_call
    attempt = voter.call_attempts.create()    
    RedisCallAttempt.new(attempt.id, voter.id, campaign.id, CallAttempt::Status::RINGING, caller.id)
    # attempt = voter.call_attempts.create(:campaign => campaign, :dialer_mode => campaign.type, :status => CallAttempt::Status::RINGING, :caller_session => self, :caller => caller, call_start:  Time.now)
    update_attribute('attempt_in_progress', attempt)
    voter.update_attributes(:last_call_attempt => attempt, :last_call_attempt_time => Time.now, :caller_session => self, status: CallAttempt::Status::RINGING)
    Call.create(call_attempt: attempt, all_states: "")
    attempt    
  end
  
  
end