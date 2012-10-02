require 'resque/plugins/lock'
require 'resque-loner'

class DeactiveUnnecessaryMonitorTabsJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :background_worker
  
   def self.perform     
     monitor_tabs = Moderator.active.group('account_id').count
     monitor_tabs.each_pair do |key, value|
       if value >= 4
         account = Account.find(key)
         account.moderators.last_hour.active.order('created_at ASC').limit(4).each do |moderator|
           moderator.update_attributes(active: false)
         end
       end      
     end
   end
end
