module FccCompliance
  def self.abandon_rate(answer_count, abandon_count)
    divisor = answer_count + abandon_count
    divisor = divisor.zero? ? 1 : divisor
    abandon_count.to_f / divisor
  end
end