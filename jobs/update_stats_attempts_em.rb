require 'resque-loner'
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"


class UpdateStatsAttemptsEm
  include Resque::Plugins::UniqueJob
  @queue = :twilio_stats_attempt
  
  def self.perform
    results = []
    twillio_lib = TwilioLib.new    
    call_attempts = CallAttempt.where("status in (?) and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') and sid is not null and service_provider != 'voxeo'", ['Message delivered', 'Call completed with success.', 'Call abandoned', 'Hangup or answering machine']).limit(1000)
      EM.synchrony do
        concurrency = 1000
        EM::Synchrony::Iterator.new(call_attempts, concurrency).map do |attempt, iter|
          http = twillio_lib.update_twilio_stats_by_model_em(attempt)
          http.callback { 
            twillio_lib.twilio_xml_parse(http.response, attempt)
            results << attempt
            iter.return(http)      
             }
          http.errback { iter.return(http) }
        end        
        CallAttempt.import results, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                          :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]
        EventMachine.stop
      end
  end
  
end