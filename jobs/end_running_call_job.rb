##
# Disconnect the call identified by the given `call_sid`.
# Queued by +Call#hungup+ and +CallerSession#end_running_call+.
# Applies to +WebuiCallerSession+, +PhonesOnlyCallerSession+ &
# +Voter+ parties.
#
# ### Metrics
#
# - failed count
#
# ### Monitoring
#
# Alert conditions:
#
# - 2 or more failures in 5 minutes
#
class EndRunningCallJob
  include Sidekiq::Worker
  # Retries should occur in lower-level dependences (ie `TwilioLib` or `Providers::Phone::Call`).
  # Sidekiq should not be used to retry it will almost certainly retry after
  # the call has ended.
  sidekiq_options :retry => false
  sidekiq_options :failures => true

   def perform(call_sid)
     t = TwilioLib.new
     t.end_call_sync(call_sid)
   end
end