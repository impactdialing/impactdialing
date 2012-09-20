require 'redis/hash_key'
class RedisCallAttempt
  include Redis::Objects
  
  def self.load_call_attempt_info(call_attempt_id, call_attempt)
    call_attempt(call_attempt_id).bulk_set(call_attempt.attributes.to_options)
  end
  
    
  def self.call_attempt(call_attempt_id)
    Redis::HashKey.new("call_attempt:#{call_attempt_id}", $redis_call_flow_connection)        
  end
  
  
  def self.connect_call(call_attempt_id, caller_id, caller_session_id)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::INPROGRESS, connecttime: Time.now, caller_id: caller_id, 
    caller_session_id: caller_session_id})      
  end
  
  def self.abandon_call(call_attempt_id)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::ABANDONED, connecttime: Time.now, call_end: Time.now, 
    wrapup_time: Time.now})
  end
  
  def self.end_answered_call(call_attempt_id)
    call_attempt(call_attempt_id).store("call_end", Time.now)
  end
  
  def self.answered_by_machine(call_attempt_id, status)
    call_attempt(call_attempt_id).bulk_set({status: status, connecttime: Time.now, call_end: Time.now, wrapup_time: Time.now})  
  end
  
  def self.end_answered_by_machine(call_attempt_id)
    call_attempt(call_attempt_id).bulk_set({call_end: Time.now, wrapup_time: Time.now})  
  end
  
  def self.set_status(call_attempt_id, status)
    call_attempt(call_attempt_id).store("status", status)    
  end
  
  def self.disconnect_call(call_attempt_id, recording_duration, recording_url)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::SUCCESS, recording_duration: recording_duration, recording_url: recording_url})    
  end
  
  def self.wrapup(call_attempt_id)
    call_attempt(call_attempt_id).store("wrapup_time", Time.now)
  end
  
  def self.schedule_for_later(call_attempt_id, scheduled_date)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::SCHEDULED, scheduled_date: scheduled_date})            
  end
  
  def self.caller_session_id(call_attempt_id)
    read(call_attempt_id)['caller_session_id']
  end
  
  def self.set_voter_response_processed(call_attempt_id)
    call_attempt(call_attempt_id).store("voter_response_processed", true)    
  end
  
  

  def self.end_unanswered_call(call_attempt_id, status)
    call_attempt(call_attempt_id).bulk_set({status: status, call_end: Time.now, wrapup_time: Time.now})  
  end
  
  def self.read(call_attempt_id)
    call_attempt(call_attempt_id).all
  end
  
  def self.update_call_sid(call_attempt_id, sid)
    call_attempt(call_attempt_id).store("sid", sid)
  end
  
  def self.failed_call(call_attempt_id)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::FAILED, wrapup_time: Time.now})
  end
  
  def self.call_answered?(call_attempt_id)
    call_attempt = read(call_attempt_id)
    !call_attempt['connecttime'].blank?
  end
  
  def self.call_not_wrapped_up?(call_attempt_id)
    call_attempt = read(call_attempt_id)
    !call_attempt['connecttime'].blank? && call_attempt['wrapup_time'].blank?
  end
  
  def self.delete(call_attempt_id)
    call_attempt(call_attempt_id).clear 
  end
  
end