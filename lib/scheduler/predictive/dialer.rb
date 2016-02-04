class Scheduler::Predictive::Dialer < Scheduler::Predictive::Schedule
  def process(campaign)
    CalculateDialsJob.add_to_queue(campaign.id)
  end
end
