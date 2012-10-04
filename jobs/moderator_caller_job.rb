class ModeratorCallerJob 
  include Sidekiq::Worker
  @queue = :moderator_flow  
  def self.perform(caller_session_id, event)         
    caller_session = CallerSession.find(caller_session_id)
    caller_session.send(event)
  end
end
