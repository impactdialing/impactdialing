require 'resque/plugins/lock'
class SimulatorJob 
  extend Resque::Plugins::Lock
  @queue = :simulator


   def self.perform(campaign_id)
     
   end
end