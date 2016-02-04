namespace :scheduler do
  task :run => :environment do
    require_relative '../scheduler'

    Scheduler.boot!

    sleep
  end
end
