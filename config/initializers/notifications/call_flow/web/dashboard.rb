ActiveSupport::Notifications.subscribe('call_flow.caller_session.created') do |name, start, finish, id, payload|  # current initialize
  CallFlow::Web::Event.publish(payload[:account_id], 'caller_session.created', payload)
end

ActiveSupport::Notifications.subscribe('call_flow.caller.state_changed') do |name, start, finish, id, payload|  # current initialize
  CallFlow::Web::Event.publish(payload[:account_id], 'caller.state_change', payload)
end

ActiveSupport::Notifications.subscribe('call_flow.caller.state_deleted') do |name, start, finish, id, payload|
  CallFlow::Web::Event.publish(payload[:account_id], 'caller.state_deleted', payload)
end

ActiveSupport::Notifications.subscribe('campaigns.created') do |name, start, finish, id, payload|
  campaign = payload[:campaign]
  CallFlow::Web::Event.publish(campaign.account_id, 'campaigns.created', payload)
end

ActiveSupport::Notifications.subscribe('campaigns.archived') do |name, start, finish, id, payload|
  campaign = payload[:campaign]
  CallFlow::Web::Event.publish(campaign.account_id, 'campaigns.archived', payload)
end
