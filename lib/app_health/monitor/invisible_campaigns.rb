module AppHealth
  module Monitor
    class InvisibleCampaigns

    private
      def invisible_campaign_ids
        @invisible_campaign_ids ||= Campaign.where("id in (select distinct campaign_id from caller_sessions where on_call = 1 )").where(type: 'Predictive').pluck(:id) - RedisPredictiveCampaign.running_campaigns.map(&:to_i)
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
        "#{time} - #{invisible_campaign_ids}"
      end

      def alarm_description
        "Invisible campaign alert"
      end

      def alarm_details
        invisible_campaign_ids.to_json
      end

      def alert_if_not_ok
        if ok?
          true
        else
          invisible_campaign_ids.each do |id|
            RedisPredictiveCampaign.add(id, 'Predictive')
          end
          puts('Invisible campaigns fixed: ' + alarm_details)
          false
        end
      end

      def ok?
        invisible_campaign_ids.empty?
      end
    end
  end
end
