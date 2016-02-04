class Scheduler::Predictive::Simulator < Scheduler::Predictive::Schedule
  def process(campaign)
    Resque.enqueue(SimulatorJob, campaign.id)
  end
end
