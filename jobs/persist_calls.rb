require 'resque-loner'
require 'librato_resque'

##
# Run periodically to persist call data from redis to the relational database.
# Call data is pushed to a redis list based on the call outcome. This job
# processes each list in turn and imports call data to the appropriate places.
#
# ### Metrics
#
# - completed
# - failed
# - timing
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure (WARNING: Exception rescued in a few spots)
# - stops reporting for 5 minutes
#
# todo: stop rescuing exception
class PersistCalls
  LIMIT = 1000
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @queue = :persist_jobs

  def self.perform
    abandoned_calls(LIMIT)
    unanswered_calls(LIMIT*3)
    machine_calls(LIMIT)
    disconnected_calls(LIMIT)
    wrapped_up_calls(LIMIT)
  end

  def self.multipop(connection, list_name, num)
    num_of_elements = connection.llen list_name
    num_to_pop = num_of_elements < num ? num_of_elements : num
    result = []
    num_to_pop.times do |x|
      element = connection.lpop list_name
      result << JSON.parse(element) unless element.nil?
    end
    result
  end

  def self.multipush(connection, list_name, data)
    data.each do |element|
      connection.lpush(list_name, element.to_json)
    end
  end

  def self.safe_pop(connection, list_name, number)
    data = multipop(connection, list_name, number)
    begin
      yield data
    rescue Resque::TermException => e
      Rails.logger.info "Shutting down. Saving popped data. [safe_pop]"
      ImpactPlatform::Metrics::JobStatus.sigterm(self.to_s.underscore)
      multipush(connection, list_name, data)
    rescue => exception
      multipush(connection, list_name, data)
      raise
    end
  end

  def self.setup_bitmasks(klass, collection, bitmask_columns)
    columns = klass.column_names
    values  = collection.compact.map do |object|
      columns.map do |column|
        if bitmask_columns.include?(column)
          object.send("#{column}_before_type_cast") 
        else
          object.send(column)
        end
      end
    end
    [columns, values]
  end

  def self.import_households(households)
    columns, values = setup_bitmasks(Household, households, ['blocked'])

    # skip validations - uniqueness validation fails; ar import doesn't handle this case
    # the db has fk constraints as of Dec 2014
    Household.import columns, values, validate: false, on_duplicate_key_update: [
      :status,
      :presented_at,
      :updated_at
    ]
  end

  # def self.cache_last_attempt_status
  def self.import_voters(voters)
    columns, values = setup_bitmasks(Voter, voters, ['enabled'])
    Voter.import columns, values, on_duplicate_key_update: [
      :status,
      :caller_id,
      :caller_session_id
    ]
  end

  def self.import_call_attempts(call_attempts)
    CallAttempt.import call_attempts,
      on_duplicate_key_update: [
        :status, :call_end, :connecttime, :caller_id,
        :scheduled_date, :recording_url, :recording_duration,
        :voter_response_processed, :wrapup_time, :voter_id,
        :recording_id, :recording_delivered_manually
    ]
  end

  def self.call_valid?(call)
    call and (call_attempt = call.call_attempt) and call_attempt.household
  end

  def self.process_calls_base(connection, list_name, num)
    safe_pop(connection, list_name, num) do |calls_data|
      calls = Call.where(id: calls_data.map { |c| c['id'] }).includes(call_attempt: [:household]).each_with_object({}) do |call, memo|
        # todo: ^^ change to CallAttempt.where(id: calls_data.map{|c| c['id']}).includes(:household).each_with_object({}) do |call_attempt, memo|
        memo[call.id] = call
      end
      result = calls_data.each_with_object({call_attempts: [], households: []}) do |call_data, memo|
        call = calls[call_data['id'].to_i]
        
        next unless call_valid?(call)
        
        call_attempt = call.call_attempt
        household    = call_attempt.household
        
        yield(call_data, call_attempt)

        household.dialed(call_attempt)

        memo[:call_attempts] << call_attempt
        memo[:households] << household
      end

      import_call_attempts(result[:call_attempts])
      import_households(result[:households])
    end
  end

  def self.abandoned_calls(num)
    process_calls_base($redis_call_flow_connection, "abandoned_call_list", num) do |abandoned_call_data, call_attempt|
      call_attempt.abandoned(abandoned_call_data['current_time'])
    end
  end

  def self.unanswered_calls(num)
    process_calls_base($redis_call_end_connection, "not_answered_call_list", num) do |unanswered_call_data, call_attempt|
      call_attempt.end_unanswered_call(unanswered_call_data['call_status'], unanswered_call_data['current_time'])
    end
  end

  def self.machine_calls(num)
    process_calls_base($redis_call_flow_connection, "end_answered_by_machine_call_list", num) do |unanswered_call_data, call_attempt|
      connect_time      = RedisCallFlow.processing_by_machine_call_hash[unanswered_call_data['id']]
      message_drop_info = RedisCallFlow.get_message_drop_info(unanswered_call_data['id'])
      call_attempt.end_answered_by_machine(connect_time, unanswered_call_data['current_time'], message_drop_info['recording_id'], message_drop_info['drop_type'])
    end
  end

  def self.disconnected_calls(num)
    process_calls_base($redis_call_flow_connection, "disconnected_call_list", num) do |disconnected_call_data, call_attempt|
      call_attempt.disconnect_call(disconnected_call_data['current_time'], disconnected_call_data['recording_duration'],
                                   disconnected_call_data['recording_url'], disconnected_call_data['caller_id'])
    end
  end

  def self.wrapped_up_calls(num)
    updated_call_attempts = []
    updated_voters        = []
    safe_pop($redis_call_flow_connection, "wrapped_up_call_list", num) do |wrapped_up_calls|
      call_attempt_ids = wrapped_up_calls.map{ |c| c['id'] }
      call_attempts    = CallAttempt.includes({household: [:voters]}, :campaign).where(id: call_attempt_ids).each_with_object({}) do |call_attempt, memo|
        memo[call_attempt.id] = call_attempt
      end
      voter_ids = wrapped_up_calls.map{|c| c['voter_id']}
      voters    = Voter.where(id: voter_ids).each_with_object({}) do |voter, memo|
        memo[voter.id] = voter
      end
      wrapped_up_calls.each do |wrapped_up_call|
        call_attempt = call_attempts[wrapped_up_call['id'].to_i]
        voter        = voters[wrapped_up_call['voter_id'].to_i]

        call_attempt.wrapup_now(wrapped_up_call['current_time'], wrapped_up_call['caller_type'], wrapped_up_call['voter_id'])
        voter.dispositioned(call_attempt) 

        updated_call_attempts << call_attempt
        updated_voters << voter
      end
      import_call_attempts(updated_call_attempts)
      import_voters(updated_voters)
    end
  end
end
