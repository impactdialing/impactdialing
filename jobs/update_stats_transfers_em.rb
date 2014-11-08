require 'resque-loner'
require 'em-http-request'
require "em-synchrony"
require "em-synchrony/em-http"

##
# Pull down call data for +TransferAttempt+ records from Twilio for billing purposes.
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
class UpdateStatsTransfersEm
  include Resque::Plugins::UniqueJob
  @queue = :twilio_stats

  def self.perform
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)

    ActiveRecord::Base.verify_active_connections!
    results           = []
    stats             = []
    twillio_lib       = TwilioLib.new
    transfer_attempts = TransferAttempt.where("status in (?) and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') and sid is not null ", ['Message delivered', 'Call completed with success.', 'Call abandoned', 'Hangup or answering machine']).limit(1000)

    EM.synchrony do
      concurrency = 100
      EM::Synchrony::Iterator.new(transfer_attempts, concurrency).map do |attempt, iter|
        http = twillio_lib.update_twilio_stats_by_model_em(attempt)
        http.callback {
          twillio_lib.twilio_xml_parse(http.response, attempt)
          results << attempt
          iter.return(http)
        }
        http.errback { iter.return(http) }
      end
      stats << TransferAttempt.import(results, {
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
