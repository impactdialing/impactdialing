desc "Update twilio call data" 

task :update_twilio_stats => :environment do
  
  CallAttempt.where("tPrice is NULL and (tStatus is NULL or tStatus = 'completed') and sid is not null").find_in_batches(:batch_size => 1000) do |attempts|
    call_attempts = []
    attempts.each do |attempt| 
      call_attempts << TwilioLib.new.update_twilio_stats_by_model attempt 
    end
    CallAttempt.import call_attempts, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                      :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]
  end
  
  TransferAttempt.where("tPrice is NULL and (tStatus is NULL or tStatus = 'completed')").find_in_batches(:batch_size => 100) do |transfer_attempts|
    transfer_attempts.each { |transfer_attempt| TwilioLib.new.update_twilio_stats_by_model transfer_attempt }
  end
  
  CallerSession.where("tPrice is NULL and (tStatus is NULL or tStatus = 'completed')").find_in_batches(:batch_size => 100) do |sessions|
    caller_sessions = []
    sessions.each do |session| 
      caller_sessions << TwilioLib.new.update_twilio_stats_by_model session 
    end
    CallerSession.import caller_sessions, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                      :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]
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