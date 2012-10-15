require 'resque-loner'
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"


class UpdateStatsEm
  include Resque::Plugins::UniqueJob
  @queue = :twilio_stats_attempt
  
  def self.perform
    results = []
    twillio_lib = TwilioLib.new    
    call_attempts = CallAttempt.where("status in (?) and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') and sid is not null", ['Call abandoned', 'Call completed with success.', 'Message delivered', 'Hangup or answering machine']).limit(10)
      EM.synchrony do
        concurrency = 100        
        EM::Synchrony::Iterator.new(call_attempts, concurrency).map do |attempt, iter|
          http = twillio_lib.update_twilio_stats_by_model_em(attempt)
          http.callback { 
            twillio_lib.twilio_xml_parse(http.response, attempt)
            results << attempt
            iter.return(http)      
             }
          http.errback { iter.return(http) }
        end        
      end
      CallAttempt.import results, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                        :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]
  end
  
end