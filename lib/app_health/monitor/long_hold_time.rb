module AppHealth
  module Monitor
    class LongHoldTime

    private
      def on_hold_time(campaign, caller_session)
        RedisStatus.on_hold_times(campaign.id, caller_session).first
      end

      def on_hold_callers(campaign)
        campaign.caller_sessions.available.pluck(:id)
      end

      def callers_exceeding_on_hold_threshold(campaign)
        on_hold_callers(campaign).keep_if do |caller_session|
          on_hold_time(campaign, caller_session).to_i > on_hold_threshold
        end
      end

      def on_hold_threshold
        (ENV['CALLER_ON_HOLD_THRESHOLD'] || 120).to_i
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
        "#{time} - #{stagnant_caller_ids}"
      end

      def alarm_description
        "Stagnant caller alert"
      end

      def alarm_details
        CallerSession.find(stagnant_caller_ids).map do |caller_session|
          { account_email: caller_session.campaign.account.users.first.email,
            campaign_name: caller_session.campaign.name,
            campaign_id: caller_session.campaign.id,
            caller_session_id: caller_session.id,
            caller_name: caller_session.caller.username
          }
        end.to_json
      end

      def alert_if_not_ok
        if ok?
          true
        else
          AppHealth::Alarm.trigger!(alarm_key, alarm_description, alarm_details)
          false
        end
      end

      def campaign_ids
        RedisPredictiveCampaign.running_campaigns
      end

      def stagnant_caller_ids
        return @stagnant_caller_ids if defined?(@stagnant_caller_ids)

        @stagnant_caller_ids = campaign_ids.inject([]) do |caller_ids, campaign_id|
          campaign = Campaign.find(campaign_id)
          caller_ids + callers_exceeding_on_hold_threshold(campaign)
        end
      end

      def ok?
        stagnant_caller_ids.empty?
      end
    end
  end
end
