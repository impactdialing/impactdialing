require 'resque/plugins/lock'
class DialerJob 
  extend Resque::Plugins::Lock
  @queue = :dialer


   def self.perform(user_id)
     
   end
end