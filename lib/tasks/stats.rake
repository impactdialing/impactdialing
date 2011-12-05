desc "Update twilio call data" 

task :update_twilio_stats => :environment do
  #include Twilio
  #require 'active_record'
  attempts = CallAttempt.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus<3)")
  attempts.each do |attempt|
    TwilioLib.new.update_twilio_stats_by_model attempt
    if !attempt.tEndTime.nil? && attempt.call_end.blank?
      attempt.call_end=attempt.tEndTime
      attempt.save
    end
    if attempt.sid.blank? && attempt.call_end.blank?
      attempt.call_end=Time.now
      attempt.save
    end
  end
  sessions = CallerSession.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus<3)")
  sessions.each do |session|
    TwilioLib.new.update_twilio_stats_by_model session
  end
  Rake::Task['destory_phantoms'].execute
end

task :destory_phantoms => :environment do
  # find calls with Twilio shows as ended but are still logged into our system
  phatom_callers = CallerSession.all(:conditions=>"on_call = 1 and tDuration is not NULL")
  phatom_callers.each do |phantom|
    phantom.end_running_call
    phantom.on_call=0
    phantom.save
    message="killed Phantom #{phantom.id} (#{phantom.campaign.name})"
    puts message
    Postoffice.deliver_feedback(message)
  end
end