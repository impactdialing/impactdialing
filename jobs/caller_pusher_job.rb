class CallerPusherJob
  include Sidekiq::Worker
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, event)
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.class.to_s.underscore)
    
    caller_session = CallerSession.find(caller_session_id)
    caller_session.send(event)
    
    metrics.completed
  end
end
