module ResqueHelpers
  def resque_jobs(queue)
    Resque.peek(queue, 0, 100)
  end

  def sidekiq_jobs(queue_name)
    Sidekiq::Queue.new(queue_name).map(&:item)
  end
end

RSpec::Matchers.define :have_queued do |job_class|
  jobs = nil
  match do |actual|
    queue_type, queue_name = *actual
    jobs                   = send("#{queue_type}_jobs", queue_name)
    expected               = {
      'class' => job_class.to_s,
      'args'  => [*@job_args]
    }
    jobs.include?(expected) or expected.keys.all? do |key|
      jobs.first.present? and jobs.first[key] == expected[key]
    end
  end

  failure_message do |actual|
    "expected #{actual} to have queued #{job_class} with #{@job_args}\ngot #{jobs}"
  end

  chain :with do |*args|
    @job_args = [*args]
  end
end

