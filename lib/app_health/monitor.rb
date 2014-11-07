# Procfile: app_health: bundle exec rake monitor_app_health
require 'app_health/monitor/recycle_rate_violations'
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
        RecycleRateViolations.alert_if_not_ok

        LibratoSidekiq.record_stats

        sleep(app_health_run_interval.to_i)
      end
    end
  end
end
