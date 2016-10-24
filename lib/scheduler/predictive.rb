##
# Base predictive work scheduler
#
# Loop endlessly, queuing SimulatorJob and CalculateDialsJob
# every 30 and 3 seconds respectively for each predictive
# campaign with callers logged in.
#
# Each job is queued from its own Celluloid Actor.
# See Scheduler::Predictive::Simulator and
# Scheduler::Predictive::Dialer.
#
# Celluloid::SupervisionGroup handles actor setup/teardown.
#

class Scheduler::Predictive < Celluloid::SupervisionGroup
  autoload :Schedule, 'scheduler/predictive/schedule'
  autoload :Dialer, 'scheduler/predictive/dialer'
  autoload :Simulator, 'scheduler/predictive/simulator'

  supervise Scheduler::Predictive::Simulator, as: :simulator, args: [60]
  supervise Scheduler::Predictive::Dialer, as: :dialer, args: [1]

  def self.run!
    super

    Celluloid::Actor[:simulator].run
    Celluloid::Actor[:dialer].run
  end
end
