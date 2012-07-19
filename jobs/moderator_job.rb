require 'resque/plugins/lock'
require 'resque-loner'

class ModeratorJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :moderator_job
  
   def self.perform(campaign_id) 
     pub_sub = MonitorPubSub.new    
     pub_sub.push_to_monitor_screen
   end
end