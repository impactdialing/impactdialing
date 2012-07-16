require 'resque/plugins/lock'
require 'resque-loner'

class ModeratorJob 
  extend Resque::Plugins::Lock
  include Resque::Plugins::UniqueJob
  @queue = :moderator_job
  
   def self.perform     
     Moderator.last_hour.active.select('session, account_id') do |moderator|
       account = Account.find(moderator.account_id)
       account.campaigns.each do | campaign |
         moderator_campaign = ModeratorCampaign.redis.get("moderator-#{campaign.id}")
         EM.run {
           deferrable = Pusher[moderator.session].trigger_async(event, moderator_campaign)
           deferrable.callback {}
           deferrable.errback { |error| }
          }         
       end
     end
   end
end