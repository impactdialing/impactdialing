RAILS_ROOT = File.expand_path('../..', __FILE__)
require File.join(RAILS_ROOT, 'config/environment')

loop do
  begin
    monitors = Moderators.active
    monitors.each do |monitor|
      campaigns = monitor.account.campaigns
      campaigns.each do |campaign|
        Moderator.publish_event(campaign, )
      end
      
    end
    
  rescue Exception => e
  end
end