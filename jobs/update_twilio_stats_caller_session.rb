require 'resque-loner'
require 'librato_resque'

##
# Pull down call data for +WebuiCallerSession+ & +PhonesOnlyCallerSession+ records
# from Twilio for billing purposes.
#
# ### Metrics
#
# - completed
# - failed
# - timing
#
# ### Monitoring
#
# Alert conditions:
#
# - failed
# - stops reporting for 5 minutes
#
class UpdateTwilioStatsCallerSession
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @queue = :twilio_stats

  def self.perform
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
  end
end