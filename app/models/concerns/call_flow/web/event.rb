module CallFlow
  module Web
    class Event
      private
        def self.enabled?
            return true if defined?(@@var) && @@var
            return (not Rails.env.test?)
        end

        def self.enable!
          @@var = true
        end

      public
        def self.publish(account_id, event, payload)
          return unless enabled?
          channel = CallFlow::Web::Event::Channel.new(account_id)
          RescueRetryNotify.on(Pusher::HTTPError, 1) do
            Pusher.trigger(channel.name, event, payload)
          end
        puts "published pusher event #{event}, #{channel.name}"
        end

        def publish
          self.class.publish(channel_name, event, payload)
        end
    end
  end
end
