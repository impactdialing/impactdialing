class Predictive < Campaign
  include SidekiqEvents


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

  def self.dial_campaign?(campaign_id)
    Resque.redis.exists("dial_campaign:#{campaign_id}")
  end

  def dialing_count
    call_attempts.with_status(CallAttempt::Status::READY).between(10.seconds.ago, Time.now).size
  end

  def number_of_voters_to_dial
    num_to_call = 0
    dials_made = call_attempts.between(10.minutes.ago, Time.now).size
    # if dials_made == 0 || !abandon_rate_acceptable?
    if dials_made == 0
      num_to_call = caller_sessions.available.size - call_attempts.with_status(CallAttempt::Status::RINGING).between(15.seconds.ago, Time.now).size
    else
      num_to_call = number_of_simulated_voters_to_dial
    end
    num_to_call
  end

  def choose_voters_to_dial(num_voters)
    return [] if num_voters < 1
    # scheduled_voters = all_voters.scheduled.limit(num_voters)
    # num_voters_to_call = (num_voters - (priority_voters.size + scheduled_voters.size))
    limit_voters = num_voters <= 0 ? 0 : num_voters
    blocked = account.blocked_numbers.for_campaign(self).pluck(:number)
    voters =  all_voters.last_call_attempt_before_recycle_rate(recycle_rate).
      to_be_dialed.without(blocked).limit(limit_voters).pluck(:id)
    set_voter_status_to_read_for_dial!(voters)
    check_campaign_out_of_numbers(voters)
    voters
  end

  def set_voter_status_to_read_for_dial!(voters)
    Voter.where(id: voters).update_all(status: CallAttempt::Status::READY)
  end

  def check_campaign_out_of_numbers(voters)
    if voters.blank?
      caller_sessions.available.pluck(:id).each { |id| enqueue_call_flow(CampaignOutOfNumbersJob, [id]) }
    end
  end


  def abandon_rate_acceptable?
    answered_dials = call_attempts.between(Time.at(1334561385) , Time.now).with_status([CallAttempt::Status::SUCCESS, CallAttempt::Status::SCHEDULED]).size
    abandon_count = call_attempts.between(Time.at(1334561385) , Time.now).with_status(CallAttempt::Status::ABANDONED).size
    abandon_rate = abandon_count.to_f/answered_dials
    abandon_rate <= acceptable_abandon_rate
  end

  def number_of_simulated_voters_to_dial
    available_callers = caller_sessions.available.size
    dials_to_make = (best_dials_simulated * available_callers) - call_attempts.with_status(CallAttempt::Status::RINGING).between(15.seconds.ago, Time.now).size
    dials_to_make.to_i
  end

  def self.do_not_call_in_production?(campaign_id)
    !Resque.redis.exists("do_not_call:#{campaign_id}")
  end
  
  def get_twilio_limit
    Resque.redis.get("twilio_limit").try(:to_i) || 4   
  end


  def best_dials_simulated
    simulated_values.nil? ? 1 : simulated_values.best_dials.nil? ? 1 : simulated_values.best_dials.ceil > get_twilio_limit ? get_twilio_limit : simulated_values.best_dials.ceil
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
