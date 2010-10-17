desc "Update twilio call data" 

task :update_twilio_stats => :environment do
  #include Twilio
  #require 'active_record'
  attempts = CallAttempt.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus<3)")
  attempts.each do |attempt|
    Twilio.new.update_twilio_stats_by_model attempt
    if !attempt.tEndTime.nil? && call_end.blank?
      attempt=call_end=tEndTime
      attempt.save
    end
    if attempt.sid.blank? && attempt.call_end.blank?
      attempt.call_end=Time.now
      attempt.save
    end
  end
  sessions = CallerSession.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus<3)")
  sessions.each do |session|
    Twilio.new.update_twilio_stats_by_model session
  end
end