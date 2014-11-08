require 'resque-loner'

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
  @queue = :background_worker

  def self.perform
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)

    t = TwilioLib.new(TWILIO_ACCOUNT,TWILIO_AUTH)
    CallerSession.on_call.where("updated_at < ? ", 5.minutes.ago).each do |cs|
      begin
        if cs.sid.starts_with?("CA")
          call_response = Hash.from_xml(t.call("GET", "Calls/" + cs.sid, {}))['TwilioResponse']['Call']
          cs.end_running_call if call_response.try(:[],"Status") == 'completed'
        end
      rescue Exception => e
        metrics.error
        Rails.logger.error("#{self} Exception: #{e.class}: #{e.message}")
        Rails.logger.error("#{self} Exception Backtrace: #{e.backtrace}")
      end
    end
    RedisCallerSession.phantom_callers.each do |cs|
      caller_session = CallerSession.find(cs)
      caller_session.end_running_call
      RedisCallerSession.remove_phantom_caller(cs)
    end
    CallerSession.on_call.where("updated_at < ? and endtime is not null", 5.minutes.ago).each {|x| x.end_running_call}

    metrics.completed
  end
end