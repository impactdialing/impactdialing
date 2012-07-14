
class Predictive < Campaign
    
  def dial
    num_to_call = number_of_voters_to_dial
    Rails.logger.info "Campaign: #{self.id} - num_to_call #{num_to_call}"    
    return if  num_to_call <= 0
    EM.synchrony do
      concurrency = 8
      voters_to_dial = choose_voters_to_dial(num_to_call)
      EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
        voter.dial_predictive_em(iter)
        Moderator.update_dials_in_progress_sync(self)
      end      
      EventMachine.stop
    end
  end
  
  def dial_resque
    num_to_call = number_of_voters_to_dial
    Rails.logger.info "Campaign: #{self.id} - num_to_call #{num_to_call}"    
    return if  num_to_call <= 0    
    update_attributes(calls_in_progress: true)
    Resque.enqueue(DialerJob, self.id, num_to_call)
  end
  
  def number_of_voters_to_dial
    num_to_call = 0
    dials_made = call_attempts.size
    # if dials_made == 0 || !abandon_rate_acceptable?
    if dials_made == 0
      num_to_call = callers_available_for_call.size - call_attempts.between(20.seconds.ago, Time.now).with_status(CallAttempt::Status::RINGING).size
    else
      num_to_call = number_of_simulated_voters_to_dial
    end
    num_to_call
  end
  
  def choose_voters_to_dial(num_voters)
    return [] if num_voters < 1
    priority_voters = all_voters.priority_voters.limit(num_voters)
    scheduled_voters = all_voters.scheduled.limit(num_voters)
    num_voters_to_call = (num_voters - (priority_voters.size + scheduled_voters.size))
    limit_voters = num_voters_to_call <= 0 ? 0 : num_voters_to_call
    voters =  priority_voters + scheduled_voters + all_voters.last_call_attempt_before_recycle_rate(recycle_rate).to_be_dialed.without(account.blocked_numbers.for_campaign(self).map(&:number)).limit(limit_voters)
    voters[0..num_voters-1]    
  end
  
  
  def abandon_rate_acceptable?
    answered_dials = call_attempts.between(Time.at(1334561385) , Time.now).with_status([CallAttempt::Status::SUCCESS, CallAttempt::Status::SCHEDULED]).size
    abandon_count = call_attempts.between(Time.at(1334561385) , Time.now).with_status(CallAttempt::Status::ABANDONED).size
    abandon_rate = abandon_count.to_f/answered_dials
    abandon_rate <= acceptable_abandon_rate
  end
  
  def number_of_simulated_voters_to_dial
    dials_made = call_attempts.between(10.minutes.ago, Time.now)
    calls_wrapping_up = dials_made.with_status(CallAttempt::Status::SUCCESS).not_wrapped_up
    active_call_attempts = dials_made.with_status(CallAttempt::Status::INPROGRESS)
    available_callers = callers_available_for_call.size + active_call_attempts.select { |call_attempt| ((call_attempt.duration_wrapped_up > best_conversation_simulated) && (call_attempt.duration_wrapped_up < best_conversation_simulated + 15))}.size + calls_wrapping_up.select{|wrapping_up_call| (wrapping_up_call.time_to_wrapup > best_wrapup_simulated) + (wrapping_up_call.time_to_wrapup > best_wrapup_simulated + 15)}.size
    ringing_lines = dials_made.with_status(CallAttempt::Status::RINGING).between(20.seconds.ago, Time.now).size
    dials_to_make = (best_dials_simulated * available_callers) - ringing_lines
    dials_to_make.to_i
  end
  
  
  def best_dials_simulated
    simulated_values.nil? ? 1 : simulated_values.best_dials.nil? ? 1 : simulated_values.best_dials.ceil > 3 ? 3 : simulated_values.best_dials.ceil
  end

  def best_conversation_simulated
    simulated_values.nil? ? 0 : simulated_values.best_conversation.nil? ? 0 : simulated_values.best_conversation
  end

  def longest_conversation_simulated
    simulated_values.nil? ? 0 : simulated_values.longest_conversation.nil? ? 0 : simulated_values.longest_conversation
  end

  def best_wrapup_simulated
    simulated_values.nil? ? 0 : simulated_values.best_wrapup_time.nil? ? 0 : simulated_values.best_wrapup_time
  end
  
  def caller_conference_started_event(current_voter_id)
    {event: 'caller_connected_dialer',data: {}}
  end
  
  def voter_connected_event(call)
    {event: 'voter_connected_dialer', data: {call_id:  call.id, voter:  call.voter.info}}
  end
  
  def call_answered_machine_event(call_attempt)    
    Hash.new                         
  end
  
    
  
end