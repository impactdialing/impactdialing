require 'resque-loner'
require 'librato_resque'

##
# Periodically run to end stale +CallerSession+s.
#
# ### Metrics
#
# - completed
# - failed
# - timing
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - ...
#
class PhantomCallerJob
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @loner_ttl = 150
  @queue = :general

  def self.perform
    t = TwilioLib.new(TWILIO_ACCOUNT,TWILIO_AUTH)
    CallerSession.on_call.where("updated_at < ? ", 1.minute.ago).each do |cs|
      if cs.sid.starts_with?("CA")
        call_response = Hash.from_xml(t.call("GET", "Calls/" + cs.sid, {}))['TwilioResponse']['Call']
        cs.end_running_call if call_response.try(:[],"Status") == 'completed'
      end
    end
    RedisCallerSession.phantom_callers.each do |cs|
      caller_session = CallerSession.find(cs)
      caller_session.end_running_call
      RedisCallerSession.remove_phantom_caller(cs)
    end
    CallerSession.on_call.where("updated_at < ? and endtime is not null", 1.minute.ago).each {|x| x.end_running_call}
  end
end
