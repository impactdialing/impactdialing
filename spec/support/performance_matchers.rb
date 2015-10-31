RSpec::Matchers.define :be_faster_than do |threshold|
  elapsed = nil
  match do |actual|
    start_time = Time.now.to_f

    actual.call

    end_time = Time.now.to_f
    elapsed  = end_time - start_time

    elapsed < threshold
  end

  failure_message do |actual|
    "expected to execute in less than #{threshold} seconds\nexecuted in #{elapsed} seconds"
  end

  supports_block_expectations
end
