class CallFlow::Web::Event
  public
    def self.publish(channel_name, event, payload)
      RescueRetryNotify.on(Pusher::HTTPError, 1) do
        Pusher.trigger(channel_name, event, payload)
      end
    end

    def publish
      self.class.publish(channel_name, event, payload)
    end
end
