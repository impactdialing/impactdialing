ActiveSupport::Notifications.subscribe('campaigns.archived') do |name, start, finish, id, payload|
  campaign = payload[:campaign]

  if campaign.archived? 
    if campaign.callers_assigned?
      Archival::Jobs::CampaignArchived.add_to_queue(campaign.id)
    end

    if campaign.dial_queue.exists?
      CallFlow::DialQueue::Jobs::Purge.add_to_queue(campaign.id)
    end
  end
end

