class CallerPusherJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

   def perform(caller_session_id, event)
    puts ActiveRecord::Base.connection.current_database
    puts caller_session_id
    puts event

     caller_session = CallerSession.find(caller_session_id)
     caller_session.send(event)
   end
end
