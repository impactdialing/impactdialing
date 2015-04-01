module ResqueHelpers
  def resque_jobs(queue)
    Resque.peek(queue, 0, 100)
  end
end