ActiveSupport::Notifications.subscribe('scripts.saved') do |name, start, finish, id, payload|  
  script         = payload[:script]
  # let resque handle failures & decrease chances of redis error during write causing user-visible error
  Resque.enqueue(CallFlow::Web::Jobs::CacheContactFields, script.id)
end 
