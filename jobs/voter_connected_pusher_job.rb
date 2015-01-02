##
# Trigger a Pusher event for +WebuiCallerSession+ where +WebuiCallerSession#caller_type+
# is 'Twilio client', to let the browser client know a dialed line has been answered.
# This job is queued whenever a voter connects, regardless if the +CallerSession#type+ is
# +WebuiCallerSession+ or +PhonesOnlyCallerSession+ but the pusher event is only triggered
# for +WebuiCallerSession+; see +CallerEvents#publish_voter_connected+, +PreviewPowerCampaign#voter_connected_event+ & +Predictve#voter_connected_event+.
#
# ### Metrics
#
# - failed count
#
# ### Monitoring
#
# Alert conditions:
#
# - 2 or more failures within 5 minutes
#
class VoterConnectedPusherJob
  include Sidekiq::Worker
  # Retries should occur in lower-level dependencies.
  # Sidekiq should not be used to retry it will almost certainly retry after
  # the call has ended.
  sidekiq_options :retry => false
  sidekiq_options :failures => true

  def perform(caller_session_id, call_id)
  	metrics = ImpactPlatform::Metrics::JobStatus.started(self.class.to_s.underscore)
    
    caller_session = CallerSession.find(caller_session_id)
    caller_session.send('publish_voter_connected', call_id)

    metrics.completed
  end
end
