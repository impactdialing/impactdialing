module CallFlow::DialQueue::SortedSetScore
  def score(voter)
    skipped_time = voter.skipped_time.to_i
    attempt_time = voter.last_call_attempt_time.to_i
    x = if skipped_time > attempt_time
          skipped_time
        else
          attempt_time
        end
    # convert voter id to sensible decimal value to preserve ordering
    # divisor = 1_000_000_000_000_000
    divisor = 1_000_000 # most consistent precision, higher divisors cause quotient to round
    y = (BigDecimal.new(voter.id) / BigDecimal.new(divisor))
    y = y.to_s.split('.').last
    x = x.zero? ? 1 : x
    "#{x}.#{y}"
  end

  def memberize(voter)
    [score(voter), voter.phone]
  end

  def memberize_voters(voters)
    voters.map do |voter|
      memberize(voter)
    end
  end
end