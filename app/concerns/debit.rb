class Debit
  attr_reader :call_time, :quota

  def initialize(call_time, quota)
    @call_time = call_time
    @quota     = quota
  end

  def process
    call_time.debited = quota.debit(minutes)
    return call_time
  end

private
  def minutes
    (call_time.tDuration.to_f/60).ceil
  end
end
