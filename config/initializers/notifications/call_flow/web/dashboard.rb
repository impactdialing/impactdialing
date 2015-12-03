ActiveSupport::Notifications.subscribe('call_flow.caller.state_changed') do |name, start, finish, id, payload|
  dashboard_event = Dashboard::Event.new(payload)
Pusher.trigger(dashboard_event.channel, 'caller.state_change', dashboard_event.payload)
end
