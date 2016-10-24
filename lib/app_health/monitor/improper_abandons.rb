module AppHealth
  module Monitor
    class ImproperAbandons

    private
      def stagnant_campaigns_info
        @stagnant_campaigns_info ||= RedisPredictiveCampaign.running_campaigns.inject([]) do |info, campaign_id|
          campaign = Campaign.find(campaign_id)
          caller_session_ids = campaign.caller_sessions.available.pluck(:id)
          hold_times = RedisStatus.on_hold_times(campaign_id, caller_session_ids)
          longest_hold_time = hold_times.max || 0
          last_abandoned_call = campaign.call_attempts.where(status: CallAttempt::Status::ABANDONED).order(created_at: :desc).limit(1).last
          if last_abandoned_call
            time_since_last_abandoned_call = Time.zone.now - last_abandoned_call.created_at
            if time_since_last_abandoned_call < longest_hold_time
              info.push({ campaign_id: campaign_id, last_abandoned_call_id: last_abandoned_call.id})
            end
          end
          info
        end
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
        "#{time} - #{stagnant_campaigns_info}"
      end

      def alarm_description
        "Stagnant campaign alert"
      end

      def alarm_details
        stagnant_campaigns_info.to_json
      end

      def alert_if_not_ok
        if ok?
          true
        else
          puts('Improper abandon: ' + alarm_details)
          false
        end
      end

      def ok?
        stagnant_campaigns_info.empty?
      end
    end
  end
end
