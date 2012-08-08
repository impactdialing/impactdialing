require Rails.root.join("lib/redis_connection")
require 'redis/hash_key'
class RedisCallAttempt
  include Redis::Objects
  
  def initialize(call_attempt_id, voter_id, campaign_id, dialer_mode, caller_id)
    redis = RedisConnection.call_flow_connection
    call_attempt = Redis::HashKey.new("call_attempt:#{call_attempt_id}", redis)            
    call_attempt.bulk_set({voter_id: voter_id, campaign_id: campaign_id, dialer_mode: dialer_mode, 
      status: CallAttempt::Status::RINGING, caller_id: caller_id, call_start: Time.now})
  end
  
  def self.call_attempt(call_attempt_id)
    redis = RedisConnection.call_flow_connection
    Redis::HashKey.new("call_attempt:#{call_attempt_id}", redis)        
  end
  
  def self.connect_call(call_attempt_id, caller_id, caller_session_id)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::INPROGRESS, connecttime: Time.now, caller_id: caller_id, 
      caller_session_id: caller_session_id})
  end
  
  def self.abandon_call(call_attempt_id)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::ABANDONED, connecttime: Time.now, call_end: Time.now, wrapup_time: Time.now})
  end
  
  def self.end_answered_call(call_attempt_id)
    call_attempt(call_attempt_id)["call_end"] = Time.now
  end
  
  def self.answered_by_machine(call_attempt_id, status)
    call_attempt(call_attempt_id).bulk_set({status: status, connecttime: Time.now, call_end: Time.now, wrapup_time: Time.now})  
  end
  
  def self.read(call_attempt_id)
    call_attempt(call_attempt_id).all
  end
  
  def self.set_status(call_attempt_id, status)
    call_attempt(call_attempt_id)["status"] = status    
  end
  
  def self.disconnect_call(call_attempt_id, recording_duration, recording_url)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::SUCCESS, recording_duration: recording_duration, recording_url: recording_url})    
  end
  
  def self.wrapup(call_attempt_id)
    call_attempt(call_attempt_id)["wrapup_time"] = Time.now        
  end
  
  def self.schedule_for_later(call_attempt_id, scheduled_date)
    call_attempt(call_attempt_id).bulk_set({status: CallAttempt::Status::SCHEDULED, scheduled_date: scheduled_date})            
  end
  
end