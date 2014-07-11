class CallStats::Velocity
  attr_reader :record, :from_date, :to_date

private
  def answered_calls
    CallStats.call_attempts(record).where(status: CallAttempt::Status::SUCCESS)
  end

  def dials_count
    query = CallStats.call_attempts(record)
    CallStats.between(query, from_date, to_date).count
  end

  def answered_calls_count
    query = answered_calls
    CallStats.between(query).count
  end

  def calling_hours_count
    query = record.caller_sessions
    @calling_hours_count ||= CallStats.between(query, from_date, to_date).sum('tDuration') / 3600.0
  end

  def average_duration
    return 0 if answered_calls_count.zero?
    @average_duration ||= (answered_calls.sum('tDuration') / answered_calls_count).ceil
  end

public
  def initialize(record, options={})
    @record    = record
    @from_date = options[:from_date]
    @to_date   = options[:to_date]
  end

  def dial_rate
    return 0 if calling_hours_count.zero?
    (dials_count / calling_hours_count).round
  end

  def answer_rate
    return 0 if calling_hours_count.zero?
    (answered_calls_count / calling_hours_count).round
  end

  def average_call_length
    seconds = average_duration
    hours   = (seconds / 3600.0).floor
    seconds -= hours * 3600
    minutes = (seconds / 60.0).floor
    seconds -= minutes * 60
    out = []
    out << "#{hours} #{'hour'.pluralize(hours)}" if hours > 0
    out << "#{minutes} #{'minute'.pluralize(minutes)}"
    out << "#{seconds} #{'second'.pluralize(seconds)}"
    out.join(' ')
  end
end
