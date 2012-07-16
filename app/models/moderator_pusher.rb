class ModeratorPusher
  
  def push_to_screen(campaign)
    Moderator.active_moderators(campaign).each do |moderator|
      EM.run {
        deferrable = Pusher[moderator.session].trigger_async(event, data)
        deferrable.callback { 
          }
        deferrable.errback { |error|
        }
      }    
  end
end