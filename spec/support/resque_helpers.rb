module ResqueHelpers
  def resque_jobs(queue)
    Resque.peek(queue, 0, 100)
  end
end

RSpec::Matchers.define :have_queued do |job_class|
  match do |actual|
    queue_type, queue_name = *actual
    jobs                   = send("#{queue_type}_jobs", queue_name)
    expected               = {
      'class' => job_class.to_s,
      'args'  => [*@job_args]
    }
    jobs.include?(expected)
  end

  chain :with do |*args|
    @job_args = args
  end
end
