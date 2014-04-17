class CallerPusherJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

   def perform(caller_session_id, event)
    Rails.logger.error "JID-#{jid} RecycleRate CallerPusherJob CallerSession[#{caller_session_id}] Event[#{event}]"
    caller_session = CallerSession.find(caller_session_id)
    caller_session.send(event)
   end
end
