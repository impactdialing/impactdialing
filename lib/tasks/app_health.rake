require 'app_health/monitor'

desc "Infinite loop that performs various app health checks and then sleeps for 90 seconds"
task :monitor_app_health => :environment do  
  AppHealth::Monitor.run
end
