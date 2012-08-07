class RedisVoter
  include Redis::Objects
  
  def self.load_voter_info(voter_id, voter)
    voter(voter_id).bulk_set(voter.attributes.to_options)
  end
  
  def self.read(voter_id)
    voter(voter_id).all    
  end
  
  def self.voter(voter_id)
    redis = RedisConnection.call_flow_connection
    Redis::HashKey.new("voter:#{voter_id}", redis)    
  end
  
  def self.abandon_call(voter_id)
    voter(voter_id).bulk_set({status: CallAttempt::Status::ABANDONED, call_back: false, 
      caller_session_id: nil, caller_id: nil})    
  end
  
  
  def self.end_answered_call(voter_id)
    voter(voter_id).bulk_set({last_call_attempt_time: Time.now, caller_session_id: nil})
  end
  
  def self.answered_by_machine(voter_id, status)
    voter(voter_id).bulk_set({status: status, caller_session_id: nil})
  end
  
  def self.set_status(voter_id, status)
    voter(voter_id)["status"] = status    
  end
  
  def self.schedule_for_later(voter_id, scheduled_date)
    voter(voter_id).bulk_set({status: CallAttempt::Status::SCHEDULED, scheduled_date: scheduled_date, call_back: true})
  end
  
  def self.update_voter_with_attempt(voter_id, attempt_id, caller_session_id)
    voter(voter_id).bulk_set({last_call_attempt: attempt_id, last_call_attempt_time: Time.now, 
      caller_session_id: caller_session_id, status: CallAttempt::Status::RINGING})
  end
  
  
  def self.assigned_to_caller?(voter_id)
    redis = RedisConnection.call_flow_connection
    redis.hexists "voter:#{voter_id}", "caller_session_id"
  end
  
  def self.assign_to_caller(voter_id, caller_session_id)
    redis = RedisConnection.call_flow_connection
    redis.hset "voter:#{voter_id}", "caller_session_id", caller_session_id
  end
  
  def self.connect_lead_to_caller(voter_id, campaign_id)
    redis = RedisConnection.call_flow_connection
    begin
      unless RedisVoter.assigned_to_caller?(voter.id)
        RedisVoter.assign_to_caller(voter_id, RedisAvailableCaller.longest_waiting_caller(campaign_id))
      end
      if RedisVoter.assigned_to_caller?(voter.id)
        redis.pipelined do
          redis.hset "voter:#{voter_id}", "caller_id", nil      
          redis.hset "voter:#{voter_id}", "status", CallAttempt::Status::INPROGRESS      
        end
        voter.caller_session.reload      
        voter.caller_session.update_attributes(:on_call => true, :available_for_call => false)  
      end
    rescue ActiveRecord::StaleObjectError
      abandon_call
    end    
  end
  
  
end