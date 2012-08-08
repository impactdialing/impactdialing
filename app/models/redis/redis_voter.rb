require Rails.root.join("lib/redis_connection")
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
    
  def self.assigned_to_caller?(voter_id)
    voter(voter_id).has_key?("caller_session_id")
  end
  
  def self.assign_to_caller(voter_id, caller_session_id)
    voter(voter_id)["caller_session_id"] = caller_session_id    
  end
  
  def self.connect_lead_to_caller(voter_id, campaign_id)    
    if RedisVoter.assigned_to_caller?(voter_id)
      caller_session_id = RedisVoter.read(voter_id)['caller_session_id']   
    else 
      caller_session_id = RedisAvailableCaller.longest_waiting_caller(campaign_id)
      RedisVoter.assign_to_caller(voter_id, caller_session_id) 
      RedisAvailableCaller.remove_caller(caller_session_id)      
    end
    voter(voter_id).bulk_set({caller_id: RedisCallerSession.read(caller_session_id)["caller_id"], status: CallAttempt::Status::INPROGRESS})
  end
  
end