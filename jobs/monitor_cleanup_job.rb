require Rails.root.join("lib/redis_connection")
require 'resque/plugins/lock'
require 'resque-loner'



class MonitorJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :background_worker_job
  
  def self.perform
    
  end
  
   
end