require 'resque/plugins/lock'
require 'resque-loner'

class ModeratorJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :moderator_job
  
   def self.perform     
   end
end