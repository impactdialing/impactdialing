##
# Record that a pre-recorded message was dropped and the delivery mechanism.
# Currently pre-recorded messages can be dropped manually (ie caller clicks button)
# or automatically (ie Twilio Answering Machine Detection).
#
# ### Metrics
#
# - failed count
#
# ### Monitoring
#
# Alert when 2 or more failures occur within 1 hour.
#
class Providers::Phone::Jobs::DropMessageRecorder
  include Sidekiq::Worker
  # This job should only fail in exceptional circumstances. Rely on sidekiq to retry
  # w/ exponential back-off. This gives time (~20 days by default retry settings)
  # to correct any exceptions without losing data of message delivery mechanism used.
  sidekiq_options :retry => true
  sidekiq_options :failures => true

  def perform(call_id, dropped_manually)
    call = Call.includes(:call_attempt => [:caller_session, :campaign, :voter]).find(call_id)
    call.update_recording!(dropped_manually)
  end
end
