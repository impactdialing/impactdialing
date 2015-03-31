module AppHealth
  class Alarm
    def self.trigger!(key, description, details)
      instance = new
      instance.trigger!(key, description, details)
    end

    def initialize
      @pager_duty_service = ENV['PAGER_DUTY_SERVICE']
    end

    def alarm_client
      'impact-dialing-app-health'
    end

    def trigger!(key, description, details)
      notify_pager_duty(key, description, details)
    end

    def notify_pager_duty(key, description, details)
      return if @pager_duty_service.blank?

      pager_duty = Pagerduty.new(@pager_duty_service)
      pager_duty.trigger(description, {
        incident_key: key,
        client: alarm_client,
        details: details
      })
    end
  end
end
