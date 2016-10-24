# Procfile: app_health: bundle exec rake monitor_app_health
require 'app_health/monitor/recycle_rate_violations'
require 'app_health/monitor/predictive_dial_rate'
require 'app_health/monitor/long_hold_time'
require 'app_health/monitor/improper_abandons'
require 'app_health/monitor/invisible_campaigns'
require 'librato_sidekiq'

module AppHealth
  module Monitor
    def self.app_health_run_interval
      ENV['APP_HEALTH_RUN_INTERVAL'] || 90
    end

    # loop through monitor checks & sleep
    def self.run
      LibratoSidekiq.track!

      loop do
        # RecycleRateViolations.alert_if_not_ok

        PredictiveDialRate.alert_if_not_ok

        LongHoldTime.alert_if_not_ok

        ImproperAbandons.alert_if_not_ok

        InvisibleCampaigns.alert_if_not_ok

        CallFlow::Jobs::ActiveCallerMonitor.perform

        CallFlow::DialQueue::Jobs::Monitor.perform

        LibratoSidekiq.record_stats

        sleep(app_health_run_interval.to_i)
      end
    end
  end
end
