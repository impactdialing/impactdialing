desc "Update twilio call data" 

task :update_twilio_stats => :environment do
  #include Twilio
  #require 'active_record'
  attempts = CallAttempt.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus = 'completed')")
  attempts.each do |attempt|
    TwilioLib.new.update_twilio_stats_by_model attempt
  end
  
  transfer_attempts = TransferAttempt.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus = 'completed')")
  transfer_attempts.each do |transfer_attempt|
    TwilioLib.new.update_twilio_stats_by_model transfer_attempt
  end
  
  sessions = CallerSession.all(:conditions=>"tPrice is NULL and (tStatus is NULL or tStatus = 'completed')")
  sessions.each do |session|
    TwilioLib.new.update_twilio_stats_by_model session
  end
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