class CallFlow::Web::Event
  private
    def self.enabled?
      return (not Rails.env.test?)
    end

  public
    def self.publish(account_id, event, payload)
      return unless enabled?
      channel = CallFlow::Web::Event::Channel.new(account_id)
      RescueRetryNotify.on(Pusher::HTTPError, 1) do
        Pusher.trigger(channel.name, event, payload)
      end
    end

    def publish
      self.class.publish(channel_name, event, payload)
    end
end
