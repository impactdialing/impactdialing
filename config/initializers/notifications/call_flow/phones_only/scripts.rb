ActiveSupport::Notifications.subscribe('scripts.saved') do |name, start, finish, id, payload|  
  script         = payload[:script]

  if script.created_at != script.updated_at
    # created_at == updated_at => script was just created
    CachePhonesOnlyScriptQuestions.add_to_queue(script.id, 'update')
  end
end 
