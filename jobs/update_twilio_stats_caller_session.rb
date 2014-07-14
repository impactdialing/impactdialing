require 'resque-loner'
class UpdateTwilioStatsCallerSession
  include Resque::Plugins::UniqueJob
  @queue = :twilio_stats

  def self.perform
    metrics = ImpactPlatform::Metrics::JobStatus.started(self.to_s.underscore)

    ActiveRecord::Base.verify_active_connections!
    caller_sessions = []
    twillio_lib = TwilioLib.new

    WebuiCallerSession.where("endtime is not NULL and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') ").limit(100).each do |session|
        if !session.sid.nil? && !session.sid.starts_with?("CA")
          session.tEndTime = session.endtime
          session.tStartTime = session.starttime
          session.tPrice = 0.0
          caller_sessions << session
        else
          caller_sessions << twillio_lib.update_twilio_stats_by_model(session)
        end
    end
    WebuiCallerSession.import caller_sessions, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                        :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]


    caller_sessions = []
    twillio_lib = TwilioLib.new

    PhonesOnlyCallerSession.where("endtime is not NULL and tPrice is NULL and (tStatus is NULL or tStatus = 'completed') ").limit(100).each do |session|
      if !session.sid.nil? && !session.sid.starts_with?("CA")
        session.tEndTime = session.endtime
        session.tStartTime = session.starttime
        session.tPrice = 0.0
        caller_sessions << session
      else
        caller_sessions << twillio_lib.update_twilio_stats_by_model(session)
      end

    end
    PhonesOnlyCallerSession.import caller_sessions, :on_duplicate_key_update=>[:tCallSegmentSid, :tAccountSid,
                                        :tCalled, :tCaller, :tPhoneNumberSid, :tStatus, :tStartTime, :tEndTime, :tDuration, :tPrice, :tFlags]

    metrics.completed
  end
end