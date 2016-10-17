require 'resque-loner'
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"
require 'librato_resque'

##
# Pull down call data for +CallAttempt+ records from Twilio for billing purposes.
#
# ### Metrics
#
# - completed
# - failed
# - timing
#
# ### Monitoring
#
# Alert conditions:
#
# - failed
# - stops reporting for 5 minutes
#
class UpdateStatsAttemptsEm
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @loner_ttl = 150
  @queue = :twilio_stats

  def self.perform
    ActiveRecord::Base.clear_active_connections!
    twilio_lib     = TwilioLib.new
    query_statuses = ['Message delivered', 'Call completed with success.', 'Call abandoned', 'Hangup or answering machine','No answer']
    call_attempts  = CallAttempt.where('tDuration is NULL').
                                  where('tStatus IS NULL OR tStatus = ?', 'completed').
                                  where('sid IS NOT NULL').
                                  where('status in (?)', query_statuses).
                                  where("created_at > ? ", Time.now-3.months).
                                  limit(2000)
    twilio_call_attempts = call_attempts.select {|call_attempt| call_attempt.sid.starts_with?("CA")}

    EM.synchrony do
      results     = []
      concurrency = 1000

      # todo: update UpdateStatsAttemptsEm ? concurrency = 50 # twilio rest api concurrency limit per account is ~130
      EM::Synchrony::Iterator.new(twilio_call_attempts, concurrency).map do |attempt, iter|
        http = twilio_lib.update_twilio_stats_by_model_em(attempt)
        http.callback {
          twilio_lib.twilio_xml_parse(http.response, attempt)
          results << attempt.attributes
          iter.return(http)
        }
        http.errback {
          Rails.logger.error "Error: UpdateStatsAttemptsEm: Failed to fetch Twilio stats for CallAttempt[#{attempt.sid}]"
          iter.return(http)
        }
      end
      CallAttempt.import_hashes(results, {
        columns_to_update: [
          :tCallSegmentSid, :tAccountSid, :tCalled,
          :tCaller, :tPhoneNumberSid, :tStatus,
          :tStartTime, :tEndTime, :tDuration,
          :tPrice, :tFlags
        ]
      })
      EventMachine.stop
    end
  end
end
