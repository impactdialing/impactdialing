class CallFlow::Web::Event
  private
    def self.enabled?
      return (not Rails.env.test?)
    end

  public
    def self.publish(channel_name, event, payload)
      return unless enabled?
      RescueRetryNotify.on(Pusher::HTTPError, 1) do
        Pusher.trigger(channel_name, event, payload)
      end
    end

    def publish
      self.class.publish(channel_name, event, payload)
    end
end
