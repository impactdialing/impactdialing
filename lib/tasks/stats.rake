desc "Update twilio call data" 

task :update_twilio_stats => :environment do
  #include Twilio
  #require 'active_record'
  attempts = CallAttempt.all(:conditions=>"tPrice is NULL and (tStatus=2 or tStatus is NULL)")
  attempts.each do |attempt|
    Twilio.new.update_twilio_stats_by_model attempt
  end
  sessions = CallerSession.all(:conditions=>"tPrice is NULL and (tStatus=2 or tStatus is NULL)")
  sessions.each do |session|
    Twilio.new.update_twilio_stats_by_model session
  end
end