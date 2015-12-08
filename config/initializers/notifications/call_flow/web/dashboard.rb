ActiveSupport::Notifications.subscribe('call_flow.caller.state_changed') do |name, start, finish, id, payload|
  # current initialize

  channel = CallFlow::Web::Event::Channel.new(payload[:account_id])

  CallFlow::Web::Event.publish(channel.name, 'caller.state_change', payload)
end

# class CallFlow::Web::Event::Channel
#   def generate
#     raise "not implemented"
#   end
#   def name
#     raise "not implemented"
#   end
# end
#
#
# class CallFlow::Web::Event::Channel::Admin < CallFlow::Web::Event::Channel
#   def generate
#     TokenGenerator.uuid
#   end
#   def name
#     retrieve_or_generate_channel
#   end
# end
#
#
# class CallFlow::Web::Event::Channel::Caller < CallFlow::Web::Event::Channel
#   def generate
#     TokenGenerator.
#   end
#   def name
#     retrieve_or_generate_channel
#   end
# end
#
# class CallFlow::Web::Event::Payload::Admin
#   def data
#     {stuff: 'info'}.merge(other_stuff)
#   end
#   def other_stuff
#     {
#       context_sensitive: 'inspriational message'
#     }
#   end
# end
