class RedisVoter
  include Redis::Objects
  
  def self.load_voter_info(voter_id, voter)
    voter(voter_id).bulk_set(voter.attributes.to_options)
  end
  
  def self.read(voter_id)
    voter(voter_id).all    
  end
  
  def self.voter(voter_id)
    Redis::HashKey.new("voter:#{voter_id}", $redis_call_flow_connection)    
  end
  
  def self.assigned_to_caller?(voter_id)
    voter(voter_id).has_key?("caller_session_id")
  end
  
  def self.assign_to_caller(voter_id, caller_session_id)
    voter(voter_id).store('caller_session_id', caller_session_id) 
  end
  
  def self.connect_lead_to_caller(voter_id, campaign_id, call_attempt_id)

      if RedisVoter.assigned_to_caller?(voter_id)
        caller_session_id = RedisVoter.read(voter_id)['caller_session_id']   
        RedisCaller.move_waiting_to_connect_to_on_call(campaign_id, caller_session_id)
      else        
        $redis_call_flow_connection.multi do
          caller_session_id = RedisCaller.longest_waiting_caller(campaign_id)          
          lock_caller(caller_session_id, campaign_id)
        end
        unless caller_session_id.blank?
          RedisVoter.assign_to_caller(voter_id, caller_session_id)           
          RedisCallerSession.set_attempt_in_progress(caller_session_id, call_attempt_id)
          RedisCallerSession.set_voter_in_progress(caller_session_id, voter_id)      
        end
      end
      voter(voter_id).bulk_set({caller_id: RedisCallerSession.read(caller_session_id)["caller_id"], status: CallAttempt::Status::INPROGRESS})
  end
  
  def self.could_not_connect_to_available_caller?(voter_id, campaign_id)
    !assigned_to_caller?(voter_id) || RedisCaller.disconnected?(campaign_id, caller_session_id(voter_id))
  end
  
  def self.lock_caller(caller_session_id, campaign_id)
    unless caller_session_id.blank?
      RedisCaller.on_hold(campaign_id).delete(caller_session_id)
      RedisCaller.on_call(campaign_id).add(caller_session_id, Time.now.to_i)    
    end
  end
  
  def self.abandon_call(voter_id)
    voter_hash = voter(voter_id)
    voter_hash.bulk_set({status: CallAttempt::Status::ABANDONED, call_back: false})
    voter_hash.delete('caller_session_id') 
    voter_hash.delete('caller_id') 
  end
  
  def self.failed_call(voter_id)
    voter(voter_id).bulk_set({status: CallAttempt::Status::FAILED})
  end

  def self.end_answered_call(voter_id)
    voter_hash = voter(voter_id)
    voter_hash.store("last_call_attempt_time", Time.now)
    voter_hash.delete('caller_session_id')
  end
  
  def self.answered_by_machine(voter_id, status)
    voter_hash = voter(voter_id)
    voter_hash.store("status", status)
    voter_hash.delete('caller_session_id')
  end
  
  def self.end_answered_by_machine(voter_id)
    voter(voter_id).bulk_set({last_call_attempt_time: Time.now, call_back: false})
  end
  
  def self.end_unanswered_call(voter_id, status)
    voter(voter_id).bulk_set({status: status, last_call_attempt_time: Time.now, call_back: false})
  end
  
  
  def self.set_status(voter_id, status)
    voter(voter_id).store('status', status)
  end
  
  def self.schedule_for_later(voter_id, scheduled_date)
    voter(voter_id).bulk_set({status: CallAttempt::Status::SCHEDULED, scheduled_date: scheduled_date, call_back: true})
  end
    
  
  def self.caller_session_id(voter_id)
    read(voter_id)['caller_session_id']
  end
  
  
  def self.setup_call(voter_id, call_attempt_id, caller_session_id)
    voter(voter_id).bulk_set({status: CallAttempt::Status::RINGING, last_call_attempt_id: call_attempt_id, last_call_attempt_time: Time.now, caller_session_id: caller_session_id })
  end
  
  def self.setup_call_predictive(voter_id, call_attempt_id)
    voter(voter_id).bulk_set({status: CallAttempt::Status::RINGING, last_call_attempt_id: call_attempt_id, last_call_attempt_time: Time.now})
  end
  
  
  
  def self.delete(voter_id)
    voter(voter_id).clear 
  end
  
  
end