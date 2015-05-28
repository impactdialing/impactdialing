module FccCompliance
  def self.abandon_rate(answer_count, abandon_count)
    divisor = answer_count + abandon_count
    divisor = divisor.zero? ? 1 : divisor
    abandon_count.to_f / divisor
  end

  def self.abandon_rate_percent(answer_count, abandon_count)
    rate = abandon_rate(answer_count, abandon_count)
    "#{(rate * 100).to_i}%"
  end
end