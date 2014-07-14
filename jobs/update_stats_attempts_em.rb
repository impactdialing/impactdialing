require 'resque-loner'
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

class UpdateStatsAttemptsEm
  include Resque::Plugins::UniqueJob
  @queue = :twilio_stats

  def self.perform
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)

    ActiveRecord::Base.verify_active_connections!
    results = []
    stats = []
    twillio_lib = TwilioLib.new
    call_attempts = CallAttempt.where("status in (?) and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') and sid is not null ", ['Message delivered', 'Call completed with success.', 'Call abandoned', 'Hangup or answering machine']).limit(10000)

    voxeo_call_attempts = call_attempts.select {|call_attempt| call_attempt.sid.starts_with?("VX")}
    voxeo_call_attempts.each do |attempt|
      attempt.tEndTime = attempt.call_end
      attempt.tStartTime = attempt.connecttime
      attempt.tPrice = 0.0
      results << attempt
    end

    twilio_call_attempts = call_attempts.select {|call_attempt| call_attempt.sid.starts_with?("CA")}
    EM.synchrony do
      concurrency = 1000
      EM::Synchrony::Iterator.new(twilio_call_attempts, concurrency).map do |attempt, iter|
        http = twillio_lib.update_twilio_stats_by_model_em(attempt)
        http.callback {
          twillio_lib.twilio_xml_parse(http.response, attempt)
          results << attempt
          iter.return(http)
           }
        http.errback { iter.return(http) }
      end
      stats << CallAttempt.import(results, {
        :on_duplicate_key_update => [
          :tCallSegmentSid,
          :tAccountSid,
          :tCalled,
          :tCaller,
          :tPhoneNumberSid,
          :tStatus,
          :tStartTime,
          :tEndTime,
          :tDuration,
          :tPrice,
          :tFlags
        ]
      })
      EventMachine.stop
    end

    metrics.completed
  end
end