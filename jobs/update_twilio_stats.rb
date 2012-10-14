require 'resque-loner'
class UpdateTwilioStats
  include Resque::Plugins::UniqueJob
  @queue = :twilio_stats
  
  def self.perform
    CallAttempt.where("tPrice is NULL and (tStatus is NULL or tStatus = 'completed') and sid is not null").find_in_batches(:batch_size => 500) do |attempts|
      call_attempts = []
      twillio_lib = TwilioLib.new
      attempts.each do |attempt| 
        call_attempts << twillio_lib.update_twilio_stats_by_model(attempt)
      end
      CallAttempt.import call_attempts, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                        :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]
    end
    
    
    CallerSession.where("tPrice is NULL and (tStatus is NULL or tStatus = 'completed')").find_in_batches(:batch_size => 500) do |sessions|
      caller_sessions = []
      twillio_lib = TwilioLib.new
      sessions.each do |session| 
        caller_sessions << TwilioLib.new.update_twilio_stats_by_model(session)
      end
      CallerSession.import caller_sessions, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                        :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]
    end
    
  end
  
end