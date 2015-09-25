require 'impact_platform/metrics'

## Monitor possible recycle rate violations (ie calling the same voter multiple times in less than an hour)
#
# Monitor our data. Count call attempts with a created_at time in the last hour grouped by household_id.
# Given recent events (Twilio API errors) our data is probably more reliable from an
# availability/freshness perspective.
#
# Code here must be lightweight, easy to read and not create disaster potential eg long running db queries.
#
# ```
# -- alert query, run often to check for problem
#  SELECT COUNT(id) FROM call_attempts
#  WHERE created_at >= NOW() - INTERVAL 1 HOUR
#  GROUP BY household_id
#  HAVING COUNT(*) > 1
#
# -- report query, run once problem is identified
#
#  SELECT COUNT(*),household_id,GROUP_CONCAT(dialer_mode) dial_mode,
#         GROUP_CONCAT(campaign_id) campaigns,GROUP_CONCAT(status) statuses,
#         GROUP_CONCAT(created_at) time,NOW() cur_time,
#         GROUP_CONCAT(tDuration) seconds,GROUP_CONCAT(sid) SIDs
#  FROM call_attempts
#  WHERE created_at >= NOW() - INTERVAL 1 HOUR
#  GROUP BY household_id,campaign_id HAVING COUNT(*) > 1
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
        ImpactPlatform::Metrics.sample(sample_name, result.rows.size, metric_source)
      end

      # This will run often (every minute or so).
      # TODO: add useful index
      # Performance is ok (~10ms) so long as the INTERVAL is kept to a minimum.
      # Longer than an hour and this query will probably affect db performance without a proper index.
      def self.count_violators_sql
        %Q{
          SELECT COUNT(DISTINCT(id)) count FROM call_attempts
          WHERE tStartTime >= UTC_TIMESTAMP() - INTERVAL 1 HOUR
          GROUP BY household_id
          HAVING COUNT(id) > 1
        }
      end

      # This will run infrequently; when alarm condition is noticed.
      def self.inspect_violators_sql
        %Q{
          SELECT COUNT(*) count,household_id,GROUP_CONCAT(dialer_mode) dial_mode,
                 GROUP_CONCAT(campaign_id) campaigns,GROUP_CONCAT(status) statuses,
                 GROUP_CONCAT(created_at) time,NOW() cur_time,
                 GROUP_CONCAT(tDuration) seconds,GROUP_CONCAT(sid) SIDs
          FROM call_attempts
          WHERE created_at >= UTC_TIMESTAMP() - INTERVAL 1 HOUR
          GROUP BY household_id,campaign_id HAVING COUNT(*) > 1
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

      attr_reader :violator_counts

      def initialize
        @pager_duty_service = ENV['PAGER_DUTY_SERVICE']
        @violator_counts    = self.class.count_violators

        self.class.sample(violator_counts)
      end

      def ok?
        violator_counts.rows.size.zero?
      end

      def alarm_key
        time      = Time.now.strftime('%d/%m/%Y')
        campaigns = violators.first['campaigns']
        household_id  = violators.first['household_id']
        "#{time} - #{campaigns} - #{household_id}"
      end

      def alarm_description
        "#{violator_counts.rows.size} Recycle Rate Violators"
      end

      def alarm_details
        violators.to_json
      end

      def violators
        @violators ||= self.class.inspect_violators
      end

      def alert_if_not_ok
        unless ok?
          AppHealth::Alarm.trigger!(alarm_key, alarm_description, alarm_details)

          return false
        end

        return true
      end
    end
  end
end
