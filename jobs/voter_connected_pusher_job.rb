class VoterConnectedPusherJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, call_id)
  	metrics = ImpactPlatform::Metrics::JobStatus.started(self.class.to_s.underscore)
    
    caller_session = CallerSession.find(caller_session_id)
    caller_session.send('publish_voter_connected', call_id)

    metrics.completed
  end
end