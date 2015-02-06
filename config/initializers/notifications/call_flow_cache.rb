ActiveSupport::Notifications.subscribe('scripts.saved') do |name, start, finish, id, payload|  
  script         = payload[:script]
  # let resque handle failures & decrease chances of redis error during write causing user-visible error
  Resque.enqueue(CallFlow::Web::Jobs::CacheContactFields, script.id)

  if script.created_at != script.updated_at
    # created_at == updated_at => script was just created
    if script.active?
      CachePhonesOnlyScriptQuestions.add_to_queue(script.id, 'update')
    end
  end
end 

ActiveSupport::Notifications.subscribe('campaigns.saved') do |name, start, finish, id, payload|
  campaign = payload[:campaign]

  if campaign.created_at != campaign.updated_at
    if campaign.archived? and campaign.dial_queue.exists?
      CallFlow::DialQueue::Jobs::Purge.add_to_queue(campaign.id)
    end
  end
end
