require 'resque-loner'

class PersistCalls
    include Resque::Plugins::UniqueJob
    @queue = :persist_jobs
  
  def self.perform
    voters = []
    call_attempts = []
    abandoned_calls(call_attempts, voters)
    unanswered_calls(call_attempts, voters)
    machine_calls(call_attempts, voters)
    disconnected_calls(call_attempts, voters)
    Voter.import  voters, :on_duplicate_key_update=>[:status, :call_back, :caller_id, :scheduled_date]
    CallAttempt.import call_attempts,
      on_duplicate_key_update: [
        :status, :call_end, :connecttime, :caller_id,
        :scheduled_date, :recording_url, :recording_duration,
        :voter_response_processed, :wrapup_time
    ]
    call_attempts = []    
    wrapped_up_calls(call_attempts, voters)
    CallAttempt.import call_attempts, :on_duplicate_key_update=>[:wrapup_time, :voter_response_processed]

  end
  
  def self.abandoned_calls(call_attempts, voters)
    abandoned_calls = multipop(RedisCall.abandoned_call_list, 100).sort_by{|a| a['id']}
    calls = Call.where(id: abandoned_calls.map { |c| c['id'] }).
      includes(call_attempt: :voter).order(:id)
    calls.zip(abandoned_calls).each do |call, abandoned_call|
      call_attempt = call.call_attempt
      voter = call_attempt.voter
      call_attempt.abandoned(abandoned_call['current_time'])
      voter.abandoned
      call_attempts << call_attempt
      voters << voter
    end
  end
  
  def self.unanswered_calls(call_attempts, voters)
    unanswered_calls = multipop(RedisCall.not_answered_call_list, 300).sort_by { |a| a['id'] }
    calls = Call.where(id: unanswered_calls.map { |c| c['id'] }).
      includes(call_attempt: :voter).order(:id)
    calls.zip(unanswered_calls).each do |call, unanswered_call|
      call_attempt = call.call_attempt
      voter = call_attempt.voter
      call_attempt.end_unanswered_call(unanswered_call['call_status'], unanswered_call['current_time'])
      voter.end_unanswered_call(unanswered_call['call_status'])
      call_attempts << call_attempt
      voters << voter
    end    
  end
  
  def self.machine_calls(call_attempts, voters)
    unanswered_calls = multipop(RedisCall.end_answered_by_machine_call_list, 100).sort_by { |a| a['id'] }
    calls = Call.where(id: unanswered_calls.map { |c| c['id'] }).
      includes(call_attempt: :voter).order(:id)
    calls.zip(unanswered_calls).each do |call, unanswered_call|
      begin
        connect_time = RedisCall.processing_by_machine_call_hash[unanswered_call['id']]
        call_attempt = call.call_attempt
        voter = call_attempt.voter
        call_attempt.end_answered_by_machine(connect_time, unanswered_call['current_time'])
        voter.end_answered_by_machine
        call_attempts << call_attempt
        voters << voter
      rescue Exception
      end
    end    
  end
  
  def self.disconnected_calls(call_attempts, voters)
    disconnected_calls = multipop(RedisCall.disconnected_call_list ,100).sort_by { |a| a['id'] }
    calls = Call.where(id: disconnected_calls.map { |c| c['id'] }).
      includes(call_attempt: :voter).order(:id)
    calls.zip(disconnected_calls).each do |call, disconnected_call|
      begin
        call_attempt = call.call_attempt
        voter = call_attempt.voter
        call_attempt.disconnect_call(disconnected_call['current_time'], disconnected_call['recording_duration'], disconnected_call['recording_url'], disconnected_call['caller_id'] )
        voter.disconnect_call(disconnected_call['caller_id'])
        call_attempts << call_attempt
        voters << voter        
      rescue Exception
      end
    end    
  end
  
  def self.wrapped_up_calls(call_attempts, voters)    
    wrapped_up_calls = multipop(RedisCall.wrapped_up_call_list ,100).sort_by { |a| a['id'] }
    call_attempts = CallAttempt.where(id: wrapped_up_calls.map  { |c| c['id'] }).order(:id)
    call_attempts.zip(wrapped_up_calls).each do |call_attempt, wrapped_up_call|
      begin
        call_attempt.wrapup_now(wrapped_up_call['current_time'], wrapped_up_call['caller_type'])
        call_attempts << call_attempt
      rescue
      end
    end    
  end
  
  def self.multipop(list, num)
    result = []
    num.times do |x|
      element = list.shift
      result << JSON.parse(element) unless element.nil?
    end
    result
  end
  
end
