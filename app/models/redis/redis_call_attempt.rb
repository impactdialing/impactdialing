require Rails.root.join("lib/redis_connection")
require 'redis/hash_key'
class RedisCallAttempt
  include Redis::Objects
  
  def self.load_call_attempt_info(call_attempt_id, call_attempt, redis_connection)
    call_attempt(call_attempt_id, redis_connection).bulk_set(call_attempt.attributes.to_options)
  end
  
    
  def self.call_attempt(call_attempt_id, redis_connection)
    Redis::HashKey.new("call_attempt:#{call_attempt_id}", redis_connection)        
  end
  
  
  def self.connect_call(call_attempt_id, caller_id, caller_session_id, redis_connection)
    call_attempt(call_attempt_id, redis_connection).bulk_set({status: CallAttempt::Status::INPROGRESS, connecttime: Time.now, caller_id: caller_id, 
      caller_session_id: caller_session_id})      
  end
  
  def self.abandon_call(call_attempt_id, redis_connection)
    call_attempt(call_attempt_id, redis_connection).bulk_set({status: CallAttempt::Status::ABANDONED, connecttime: Time.now, call_end: Time.now, wrapup_time: Time.now})
  end
  
  def self.end_answered_call(call_attempt_id, redis_connection)
    call_attempt(call_attempt_id, redis_connection)["call_end"] = Time.now
  end
  
  def self.answered_by_machine(call_attempt_id, status, redis_connection)
    call_attempt(call_attempt_id, redis_connection).bulk_set({status: status, connecttime: Time.now, call_end: Time.now, wrapup_time: Time.now})  
  end
  
  def self.read(call_attempt_id, redis_connection)
    call_attempt(call_attempt_id, redis_connection).all
  end
  
  def self.update_call_sid(call_attempt_id, sid, redis_connection)
    call_attempt(call_attempt_id, redis_connection).store("sid", sid)
  end
  
  def self.failed_call(call_attempt_id, redis_connection)
    call_attempt(call_attempt_id, redis_connection).bulk_set({status: CallAttempt::Status::FAILED, wrapup_time: Time.now})
  end
  
  def self.set_status(call_attempt_id, status, redis_connection)
    call_attempt(call_attempt_id, redis_connection).store("status", status)    
  end
  
  def self.disconnect_call(call_attempt_id, recording_duration, recording_url, redis_connection)
    call_attempt(call_attempt_id, redis_connection).bulk_set({status: CallAttempt::Status::SUCCESS, recording_duration: recording_duration, recording_url: recording_url})    
  end
  
  def self.wrapup(call_attempt_id, redis_connection)
    call_attempt(call_attempt_id, redis_connection).store("wrapup_time", Time.now)
  end
  
  def self.schedule_for_later(call_attempt_id, scheduled_date, redis_connection)
    call_attempt(call_attempt_id, redis_connection).bulk_set({status: CallAttempt::Status::SCHEDULED, scheduled_date: scheduled_date})            
  end
  
  def self.call_not_wrapped_up?(call_attempt_id, redis_connection)
    call_attempt = read(call_attempt_id, redis_connection)
    call_attempt['connecttime'] != nil && call_attempt['wrapup_time'] != nil
  end
  
end