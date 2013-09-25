require 'resque-loner'

class PersistCalls
  LIMIT = 1000
  include Resque::Plugins::UniqueJob
  @queue = :persist_jobs

  class << self

    def perform
      puts 'PersistCalls Started...'
      abandoned_calls(LIMIT)
      unanswered_calls(LIMIT*3)
      machine_calls(LIMIT)
      disconnected_calls(LIMIT)
      wrapped_up_calls(LIMIT)
      puts 'PersistCalls Done.'
    end

    def multipop(connection, list_name, num)
      num_of_elements = connection.llen list_name
      num_to_pop = num_of_elements < num ? num_of_elements : num
      result = []
      num_to_pop.times do |x|
        element = connection.lpop list_name
        begin
          result << JSON.parse(element) unless element.nil?
        rescue Exception
        end
      end
      result
    end

    def multipush(connection, list_name, data)
      data.each do |element|
        connection.lpush(list_name, element.to_json)
      end
    end

    def safe_pop(connection, list_name, number)
      data = multipop(connection, list_name, number)
      begin
        yield data
      rescue Exception => e
        multipush(connection, list_name, data)
      end
    end

    def import_voters(voters)
      Voter.import  voters, :on_duplicate_key_update=>[:status, :call_back, :caller_id, :scheduled_date]
    end

    def import_call_attempts(call_attempts)
      CallAttempt.import call_attempts,
        on_duplicate_key_update: [
          :status, :call_end, :connecttime, :caller_id,
          :scheduled_date, :recording_url, :recording_duration,
          :voter_response_processed, :wrapup_time
      ]
    end

    def call_valid?(call)
      return false unless call
      return false unless call.call_attempt
      return false unless call.call_attempt.voter
      true
    end

    def process_calls_base(connection, list_name, num)
      safe_pop(connection, list_name, num) do |calls_data|
        calls = Call.where(id: calls_data.map { |c| c['id'] }).includes(call_attempt: :voter).each_with_object({}) do |call, memo|
          memo[call.id] = call
        end
        result = calls_data.each_with_object({voters: [], call_attempts: []}) do |call_data, memo|
          call = calls[call_data['id'].to_i]
          next unless call_valid?(call)
          call_attempt = call.call_attempt
          voter = call_attempt.voter
          yield(call_data, call_attempt, voter)
          memo[:call_attempts] << call_attempt
          memo[:voters] << voter
        end
        import_voters(result[:voters])
        import_call_attempts(result[:call_attempts])
      end
    end

    def abandoned_calls(num)
      process_calls_base($redis_call_flow_connection, "abandoned_call_list", num) do |abandoned_call_data, call_attempt, voter|
        call_attempt.abandoned(abandoned_call_data['current_time'])
        voter.abandoned
      end
    end

    def unanswered_calls(num)
      process_calls_base($redis_call_end_connection, "not_answered_call_list", num) do |unanswered_call_data, call_attempt, voter|
        call_attempt.end_unanswered_call(unanswered_call_data['call_status'], unanswered_call_data['current_time'])
        voter.end_unanswered_call(unanswered_call_data['call_status'])
      end
    end

    def machine_calls(num)
      process_calls_base($redis_call_flow_connection, "end_answered_by_machine_call_list", num) do |unanswered_call_data, call_attempt, voter|
        connect_time = RedisCallFlow.processing_by_machine_call_hash[unanswered_call_data['id']]
        call_attempt.end_answered_by_machine(connect_time, unanswered_call_data['current_time'])
        voter.end_answered_by_machine
      end
    end

    def disconnected_calls(num)
      process_calls_base($redis_call_flow_connection, "disconnected_call_list", num) do |disconnected_call_data, call_attempt, voter|
        call_attempt.disconnect_call(disconnected_call_data['current_time'], disconnected_call_data['recording_duration'],
                                     disconnected_call_data['recording_url'], disconnected_call_data['caller_id'])
        voter.disconnect_call(disconnected_call_data['caller_id'])
      end
    end

    def wrapped_up_calls(num)
      result = []
      safe_pop($redis_call_flow_connection, "wrapped_up_call_list", num) do |wrapped_up_calls|
        call_attempts = CallAttempt.where(id: wrapped_up_calls.map  { |c| c['id'] }).each_with_object({}) do |call_attempt, memo|
          memo[call_attempt.id] = call_attempt
        end
        wrapped_up_calls.each do |wrapped_up_call|
          begin
            call_attempt = call_attempts[wrapped_up_call['id'].to_i]
            call_attempt.wrapup_now(wrapped_up_call['current_time'], wrapped_up_call['caller_type'])
            result << call_attempt
          rescue
          end
        end
        CallAttempt.import result, :on_duplicate_key_update=>[:wrapup_time, :voter_response_processed]
      end
    end
  end

end
