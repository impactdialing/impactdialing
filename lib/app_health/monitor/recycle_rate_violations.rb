require 'impact_platform/metrics'

## Monitor possible recycle rate violations (ie calling the same voter multiple times in less than an hour)
#
# Monitor our data. Count call attempts with a created_at time in the last hour grouped by voter_id.
# Given recent events (Twilio API errors) our data is probably more reliable from an
# availability/freshness perspective.
#
# Code here must be lightweight, easy to read and not create disaster potential eg long running db queries.
#
# ```
# -- alert query, run often to check for problem
#  SELECT COUNT(id) FROM call_attempts
#  WHERE created_at >= NOW() - INTERVAL 1 HOUR
#  GROUP BY voter_id
#  HAVING COUNT(*) > 1
#
# -- report query, run once problem is identified
#
#  SELECT COUNT(*),voter_id,GROUP_CONCAT(dialer_mode) dial_mode,
#         GROUP_CONCAT(campaign_id) campaigns,GROUP_CONCAT(status) statuses,
#         GROUP_CONCAT(created_at) time,NOW() cur_time,
#         GROUP_CONCAT(tDuration) seconds,GROUP_CONCAT(sid) SIDs
#  FROM call_attempts
#  WHERE created_at >= NOW() - INTERVAL 1 HOUR
#  GROUP BY voter_id,campaign_id HAVING COUNT(*) > 1
# ```

module AppHealth
  module Monitor
    class RecycleRateViolations
      def self.sample_name
        'app_health.monitor.recycle_rate_violations'
      end

      def self.metric_source
        'system'
      end

      def self.sample(result)
        ImpactPlatform::Metrics.sample(sample_name, result.size, metric_source)
      end

      # This will run often (every minute or so).
      # TODO: add useful index
      # Performance is ok (~10ms) so long as the INTERVAL is kept to a minimum.
      # Longer than an hour and this query will probably affect db performance without a proper index.
      def self.count_violators_sql
        %Q{
          SELECT COUNT(DISTINCT(id)) count FROM call_attempts
          WHERE created_at >= UTC_TIMESTAMP() - INTERVAL 1 HOUR
          GROUP BY voter_id
          HAVING COUNT(id) > 1
        }
      end

      # This will run infrequently; when alarm condition is noticed.
      def self.inspect_violators_sql
        %Q{
          SELECT COUNT(*) count,voter_id,GROUP_CONCAT(dialer_mode) dial_mode,
                 GROUP_CONCAT(campaign_id) campaigns,GROUP_CONCAT(status) statuses,
                 GROUP_CONCAT(created_at) time,NOW() cur_time,
                 GROUP_CONCAT(tDuration) seconds,GROUP_CONCAT(sid) SIDs
          FROM call_attempts
          WHERE created_at >= UTC_TIMESTAMP() - INTERVAL 1 HOUR
          GROUP BY voter_id,campaign_id HAVING COUNT(*) > 1
        }
      end

      def self.db
        @db ||= ActiveRecord::Base.connection
      end
      # Main entry point. Runs 1 SQL query to check for alarm state. If results indicate alarm then run a 2nd query
      # to generate report of violators
      def self.ok?
        # any violations mean our result set is non-empty
        instance = new

        return instance.ok?
      end

      def self.alert_if_not_ok
        instance = new
        instance.alert_if_not_ok
      end

      def self.inspect_violators
        db.select_all(inspect_violators_sql)
      end

      def self.count_violators
        db.select_all(count_violators_sql)
      end

      attr_reader :violator_counts, :violators

      def initialize
        @pager_duty_service = ENV['PAGER_DUTY_SERVICE']
        @violator_counts    = self.class.count_violators

        self.class.sample(violator_counts)
      end

      def ok?
        violator_counts.size.zero?
      end

      def alert_key
        Time.now.strftime('%d/%m/%Y')
      end

      def alert_client
        'impact-dialing-app-health'
      end

      def alert_description
        "#{violator_counts.size} Recycle Rate Violators"
      end

      def alert_details
        violators.to_json
      end

      def alert_if_not_ok
        unless ok?
          @violators = self.class.inspect_violators

          alert!

          return false
        end

        return true
      end

      def alert!
        alert_by_pager_duty
        alert_by_email
      end

      def alert_by_pager_duty
        return if @pager_duty_service.blank?

        pager_duty = Pagerduty.new(@pager_duty_service)
        pager_duty.trigger(alert_description, {
          incident_key: alert_key,
          client: alert_client,
          details: alert_details
        })
      end

      def alert_by_email
        return if @pager_duty_service.present?
        # todo: alert recycle rate violations by email
      end
    end
  end
end
