module CallFlow::DialQueue::SortedSetScore
  def score(object)
    x = object.presented_at.to_i
    # convert voter id to sensible decimal value to preserve ordering
    # divisor = 1_000_000_000_000_000
    divisor = 1_000_000 # most consistent precision, higher divisors cause quotient to round
    y = (BigDecimal.new(object.id) / BigDecimal.new(divisor))
    y = y.to_s.split('.').last
    x = x.zero? ? 1 : x
    "#{x}.#{y}"
  end

  def memberize(object)
    [score(object), object.phone]
  end
end