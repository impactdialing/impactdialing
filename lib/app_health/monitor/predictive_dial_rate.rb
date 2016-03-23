module AppHealth
  module Monitor
    class PredictiveDialRate

    private
      def on_hold_times(campaign)
        RedisStatus.on_hold_times(campaign.id, *campaign.caller_sessions.available.pluck(:id))
      end

      def any_callers_exceed_on_hold_threshold?(campaign)
        on_hold_times(campaign).detect{|n| n >= on_hold_threshold}
      end

      def no_recent_dials?(campaign)
        (Time.now.utc.to_i - campaign.last_dial_time) > 60
      end

      def on_hold_threshold
        (ENV['PREDICTIVE_ON_HOLD_THRESHOLD'] || 20).to_i
      end

    public
      def self.ok?
        instance = new
        instance.ok?
      end

      def self.alert_if_not_ok
        instance = new
        instance.alert_if_not_ok
      end

      def initialize
      end

      def alarm_key
        time = Time.now.strftime('%d/%m/%Y')
        "#{time} - #{stagnant_campaign_ids}"
      end

      def alarm_description
        "#{stagnant_campaign_ids.size} campaigns have no recent dials"
      end

      def alarm_details
        {}.to_json # todo: discover & add relevant details here
      end

      def alert_if_not_ok
        unless ok?
          AppHealth::Alarm.trigger!(alarm_key, alarm_description, alarm_details)
          return false
        end
        return true
      end

      def campaign_ids
        RedisPredictiveCampaign.running_campaigns
      end

      def stagnant_campaign_ids
        return @stagnant_campaign_ids if defined?(@stagnant_campaign_ids)

        stagnant_ids = []
        campaign_ids.each do |campaign_id|
          campaign = Campaign.find(campaign_id)
          if any_callers_exceed_on_hold_threshold?(campaign) and no_recent_dials?(campaign)
            stagnant_ids << campaign_id
          end
        end
        @stagnant_campaign_ids = stagnant_ids
      end

      def ok?
        stagnant_campaign_ids.empty?
      end
    end
  end
end

