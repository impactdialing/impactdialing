class VoterConnectedPusherJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, call_id)
    caller_session = CallerSession.find(caller_session_id)
    caller_session.send('publish_voter_connected', call_id)
  end

end