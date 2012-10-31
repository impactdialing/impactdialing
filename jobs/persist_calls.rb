require 'resque-loner'
LIMIT = 1000

class PersistCalls
    include Resque::Plugins::UniqueJob
    @queue = :persist_jobs
  
  def self.perform
    voters = []
    call_attempts = []
    abandoned_calls(call_attempts, voters, LIMIT)
    unanswered_calls(call_attempts, voters, LIMIT*3)
    machine_calls(call_attempts, voters, LIMIT)
    disconnected_calls(call_attempts, voters, LIMIT)
    ActiveRecord::Base.transaction do
      Voter.import  voters, :on_duplicate_key_update=>[:status, :call_back, :caller_id, :scheduled_date]
      CallAttempt.import call_attempts,
        on_duplicate_key_update: [
          :status, :call_end, :connecttime, :caller_id,
          :scheduled_date, :recording_url, :recording_duration,
          :voter_response_processed, :wrapup_time
      ]
    end
    clean_list('abandoned_call_list', LIMIT)
    clean_list('not_answered_call_list', LIMIT*3)
    clean_list('end_answered_by_machine_call_list', LIMIT)
    clean_list('disconnected_call_list', LIMIT)
    call_attempts = []    
    wrapped_up_calls(call_attempts, voters, LIMIT)
    CallAttempt.import call_attempts, :on_duplicate_key_update=>[:wrapup_time, :voter_response_processed]
    clean_list('wrapped_up_call_list', LIMIT)
  end
  
  def self.abandoned_calls(call_attempts, voters, num)
    abandoned_calls = multiget("abandoned_call_list", num).sort_by{|a| a['id']}
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
  
  def self.unanswered_calls(call_attempts, voters, num)
    unanswered_calls = multiget("not_answered_call_list", num).sort_by { |a| a['id'] }
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
  
  def self.machine_calls(call_attempts, voters, num)
    unanswered_calls = multiget("end_answered_by_machine_call_list", num).sort_by { |a| a['id'] }
    calls = Call.where(id: unanswered_calls.map { |c| c['id'] }).
      includes(call_attempt: :voter).order(:id)
    calls.zip(unanswered_calls).each do |call, unanswered_call|
      begin
        connect_time = RedisCallFlow.processing_by_machine_call_hash[unanswered_call['id']]
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
  
  def self.disconnected_calls(call_attempts, voters, num)
    disconnected_calls = multiget("disconnected_call_list", num).sort_by { |a| a['id'] }
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
  
  def self.wrapped_up_calls(result, voters, num)
    wrapped_up_calls = multiget("wrapped_up_call_list", num).sort_by { |a| a['id'] }
    call_attempts = CallAttempt.where(id: wrapped_up_calls.map  { |c| c['id'] }).order(:id)
    call_attempts.zip(wrapped_up_calls).each do |call_attempt, wrapped_up_call|
      begin
        call_attempt.wrapup_now(wrapped_up_call['current_time'], wrapped_up_call['caller_type'])
        result << call_attempt
      rescue
      end
    end
  end
  
  def self.multiget(list_name, num)
    num_of_elements = connection.llen list_name
    num_to_pop = num_of_elements < num ? num_of_elements : num
    connection.lrange(list_name, 0, num).compact.map { |x| JSON.parse(x) }
  end

  def self.clean_list(list_name, num)
    connection.ltrim(list_name, num, -1)
  end

  def self.connection
    $redis_call_flow_connection
  end
  
end
