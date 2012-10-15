require 'resque-loner'
class UpdateTwilioStatsCallAttempt
  include Resque::Plugins::UniqueJob
  @queue = :twilio_stats_attempt
  
  def self.perform
    call_attempts = []
    twillio_lib = TwilioLib.new    
    CallAttempt.where("status in (?) and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') and sid is not null", ['Message delivered', 'Call completed with success.', 'Call abandoned', 'Hangup or answering machine']).limit(2000).each do |attempt|
      call_attempts << twillio_lib.update_twilio_stats_by_model(attempt)
    end
      CallAttempt.import call_attempts, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                        :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]
  end
  
end