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

  def items
    if scoped_to?(:call_attempts)
      call_attempts.from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)').between(@from_date, @to_date)
    elsif scoped_to?(:all_voters)
      all_voters.last_call_attempt_within(@from_date, @to_date)
    else
      raise ArgumentError, "Unknown scoped_to in CallStats::ByStatus: #{scoped_to}. Use one of :call_attempts, :all_voters."
    end
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
    @by_status_counts ||= by_status.count
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
    n = 0
    CallAttempt::Status.machine_answered_list.each do |status|
      n += with_status_in_range_count(status)
    end
    n
  end

  def machine_left_message_count
    with_status_in_range_count(CallAttempt::Status::VOICEMAIL)
  end

  def machine_left_message_percent
    n = machine_left_message_count || 0
    perc = (n / (machine_answered_count.zero? ? 1 : machine_answered_count).to_f) * 100
    "#{perc.round}%"
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
    query = items

    query = yield query if block_given?

    query.count
  end

  # def not_ringing_total_count
  #   total_count do |query|
  #     query = query.not_ringing
  #   end
  # end

  def caller_left_message_count
    items.with_manual_message_drop.count
  end

  def caller_left_message_percent
    n = caller_left_message_count || 0
    perc = (n / (answered_count.zero? ? 1 : answered_count).to_f) * 100
    "#{perc.round}%"
  end
end
