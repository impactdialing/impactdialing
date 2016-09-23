require 'resque-loner'
require 'librato_resque'

##
# Run periodically from simulator/simulator_loop.rb. Simulates a set of dials based on
# passed dial history to determine number of +Voter+ records that should be dialed next.
#
# ### Metrics
#
# - completed
# - failed
# - timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure
# - stops reporting for 2 minutes and active predictive callers > 0
#
class SimulatorJob
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @loner_ttl = 150
  @queue = :simulator_worker

  def self.perform(campaign_id)
    SimulatedValues.create!(campaign_id: campaign_id)
  end
end
