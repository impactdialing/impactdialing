ActiveSupport::Notifications.subscribe('campaigns.saved') do |name, start, finish, id, payload|
  campaign = payload[:campaign]

  if campaign.created_at != campaign.updated_at
    if campaign.archived? and campaign.callers_assigned?
      Archival::Jobs::Campaign.add_to_queue(campaign.id)
    end
  end
end
