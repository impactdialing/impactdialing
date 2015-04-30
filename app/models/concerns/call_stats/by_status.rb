class CallStats::ByStatus
  attr_reader :campaign, :scoped_to

  delegate :call_attempts, to: :campaign
  delegate :all_voters, to: :campaign
  delegate :households, to: :campaign

  def initialize(campaign, options)
    @campaign  = campaign
    @scoped_to = options[:scoped_to]
    @from_date = options[:from_date]
    @to_date   = options[:to_date]
  end

  def scoped_to?(sym)
    scoped_to == sym
  end

  def items(group_by_status_index=false)
    if scoped_to?(:call_attempts)
      if group_by_status_index
        @_call_attempts_group_index ||= call_attempts.between(@from_date, @to_date)
      else
        @_call_attempts_row_index ||= call_attempts.between(@from_date, @to_date)
      end
    elsif scoped_to?(:all_voters)
      if group_by_status_index
        @_all_voters_group_index ||= households.presented_within(@from_date, @to_date)
      else
        @_all_voters ||= households.presented_within(@from_date, @to_date)
      end
    else
      raise ArgumentError, "Unknown scoped_to in CallStats::ByStatus: #{scoped_to}. Use one of :call_attempts, :all_voters."
    end
  end

  def caller_left_message_count
    @caller_left_message_count ||= items.with_manual_message_drop.count(:id)
  end

  def machine_left_message_count
    @machine_left_message_count ||= items.with_auto_message_drop.count(:id)
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

  def by_status
    items(true).group('status')
  end

  def by_status_counts
    @by_status_counts ||= by_status.count(:id)
  end

  def with_status_in_range_count(status)
    by_status_counts[status] || 0
  end

  def answered_count
    return @answered_count if defined?(@answered_count)
    n = 0
    CallAttempt::Status.answered_list.each do |status|
      n += with_status_in_range_count(status)
    end
    @answered_count = n
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
    @abandoned_count = with_status_in_range_count(CallAttempt::Status::ABANDONED)
  end

  def ringing_count
    with_status_in_range_count(CallAttempt::Status::RINGING)
  end

  def fcc_abandon_rate
    abandoned = abandoned_count
    answered = answered_count
    if ((abandoned+answered) === 0)
    # if ((@abandoned_count + @answered_count) === 0)
      return 0
    else
      @fcc_rate = (abandoned/(abandoned+answered))
      # @fcc_rate = (@abandoned_count/(@answered_count + @abandoned_count))
    end
    return @fcc_rate
  end

  def total_count(&block)
    return @total_count if defined?(@total_count)

    query = items

    query = yield query if block_given?

    @total_count = query.count(:id)
  end
end
