class CallStats::ByStatus
  attr_reader :campaign, :scoped_to

  delegate :call_attempts, to: :campaign
  delegate :all_voters, to: :campaign

  def initialize(campaign, options)
    @campaign  = campaign
    @scoped_to = options[:scoped_to]
    @from_date = options[:from_date]
    @to_date   = options[:to_date]
  end

  def scoped_to?(sym)
    scoped_to == sym
  end

  def call_attempt_items
    call_attempts.from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)').between(@from_date, @to_date)
  end

  def voter_items
    all_voters.last_call_attempt_within(@from_date, @to_date)
  end

  def items
    if scoped_to?(:call_attempts)
      call_attempt_items
    elsif scoped_to?(:all_voters)
      voter_items
    else
      raise ArgumentError, "Unknown scoped_to in CallStats::ByStatus: #{scoped_to}. Use one of :call_attempts, :all_voters."
    end
  end

  def caller_left_message_count
    if scoped_to?(:call_attempts)
      @caller_left_message_per_attempt_count ||= call_attempt_items.with_manual_message_drop.count(:id) 
    else
      @caller_left_message_per_voter_count ||= CallAttempt.with_manual_message_drop.where(voter_id: voter_items.pluck(:id)).count(:id)
    end
  end

  def machine_left_message_count
    if scoped_to?(:call_attempts)
      @machine_left_message_per_attempt_count ||= call_attempt_items.with_auto_message_drop.count(:id)
    else
      @machine_left_message_per_voter_count ||= CallAttempt.with_auto_message_drop.where(voter_id: voter_items.pluck(:id)).count(:id)
    end
  end

  def caller_left_message_percent
    n = caller_left_message_count || 0
    perc = (n / (answered_count.zero? ? 1 : answered_count).to_f) * 100
    "#{perc.round}%"
  end

  def machine_left_message_percent
    n = machine_left_message_count || 0
    perc = (n / (machine_answered_count.zero? ? 1 : machine_answered_count).to_f) * 100
    "#{perc.round}%"
  end

  def percent_of_all_attempts(number)
    quo = number / total_count.to_f
    "#{(quo * 100).ceil}%"
  end

  def in_range
    items
  end

  def by_status
    items.group('status')
  end

  def by_status_counts
    @by_status_counts ||= by_status.count(:id)
  end

  def with_status_in_range_count(status)
    by_status_counts[status] || 0
  end

  def answered_count
    n = 0
    CallAttempt::Status.answered_list.each do |status|
      n += with_status_in_range_count(status)
    end
    n
  end

  def not_answered_count
    with_status_in_range_count(CallAttempt::Status::NOANSWER)
  end

  def busy_count
    with_status_in_range_count(CallAttempt::Status::BUSY)
  end

  def machine_answered_count
    return @machine_answered_count if defined?(@machine_answered_count)
    n = 0
    CallAttempt::Status.machine_answered_list.each do |status|
      n += with_status_in_range_count(status)
    end
    @machine_answered_count = n
  end

  def failed_count
    with_status_in_range_count(CallAttempt::Status::FAILED)
  end

  def abandoned_count
    with_status_in_range_count(CallAttempt::Status::ABANDONED)
  end

  def ringing_count
    with_status_in_range_count(CallAttempt::Status::RINGING)
  end

  def total_count(&block)
    return @total_count if defined?(@total_count)

    query = items

    query = yield query if block_given?

    @total_count = query.count(:id)
  end

  # def not_ringing_total_count
  #   total_count do |query|
  #     query = query.not_ringing
  #   end
  # end

end
