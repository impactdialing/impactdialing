class Predictive < Campaign
  
    
  def dial
    num_to_call = number_of_voters_to_dial
    Rails.logger.info "Campaign: #{self.id} - num_to_call #{num_to_call}"    
    return if  num_to_call <= 0
    EM.synchrony do
      concurrency = 8
      voters_to_dial = choose_voters_to_dial(num_to_call)
      EM::Synchrony::Iterator.new(voters_to_dial, concurrency).map do |voter, iter|
        Twillio.dial_predictive_em(iter, voter)
        Moderator.update_dials_in_progress_sync(self)
      end      
      EventMachine.stop
    end
  end
  
  def dial_resque
    set_calculate_dialing
    Resque.enqueue(CalculateDialsJob, self.id)
  end  
  
  def set_calculate_dialing
    Resque.redis.set("dial_calculate:#{self.id}", true)
    Resque.redis.expire("dial_calculate:#{self.id}", 8)
  end
  
  def calculate_dialing?
    Resque.redis.exists("dial_calculate:#{self.id}")
  end
  
    
  def increment_campaign_dial_count(counter)
    Resque.redis.incrby("dial_count:#{self.id}", counter)
  end
  
  
  def decrement_campaign_dial_count(decrement_counter)
    Resque.redis.decrby("dial_count:#{self.id}", decrement_counter)
  end
  
  def dialing_count
    begin
      count = Resque.redis.get("dial_count:#{self.id}").to_i
    rescue Exception => e
      count = 0
    end
    count <=0 ? 0 : count
  end
    
  def number_of_voters_to_dial
    num_to_call = 0
    dials_made = call_attempts.size
    # if dials_made == 0 || !abandon_rate_acceptable?
    if dials_made == 0
      num_to_call = callers_available_for_call - RedisCampaignCall.ringing(self.id).length
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
    calls_wrapping_up = RedisCampaignCall.wrapup(self.id).length
    active_call_attempts = RedisCampaignCall.inprogress(self.id).length
    available_callers = RedisCaller.on_hold_count(self.id) + RedisCampaignCall.above_average_inprogress_calls_count(self.id, best_conversation_simulated) + RedisCampaignCall.above_average_wrapup_calls_count(self.id, best_wrapup_simulated)
    ringing_lines = RedisCampaignCall.ringing(self.id).length
    dials_to_make = (best_dials_simulated * available_callers) - ringing_lines
    dials_to_make.to_i
  end
  
  
  def best_dials_simulated
    simulated_values.nil? ? 1 : simulated_values.best_dials.nil? ? 1 : simulated_values.best_dials.ceil > 3 ? 3 : simulated_values.best_dials.ceil
  end

  def best_conversation_simulated
    simulated_values.nil? ? 1000 : (simulated_values.best_conversation.nil? || simulated_values.best_conversation == 0) ? 1000 : simulated_values.best_conversation
  end

  def longest_conversation_simulated
    simulated_values.nil? ? 1000 : simulated_values.longest_conversation.nil? ? 0 : simulated_values.longest_conversation
  end

  def best_wrapup_simulated
    simulated_values.nil? ? 1000 : (simulated_values.best_wrapup_time.nil? || simulated_values.best_wrapup_time == 0) ? 1000 : simulated_values.best_wrapup_time
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