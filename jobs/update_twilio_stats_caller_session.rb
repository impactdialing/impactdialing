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

  @loner_ttl = 150
  @queue = :twilio_stats

  def self.perform
    ActiveRecord::Base.clear_active_connections!
    caller_sessions = []
    twillio_lib = TwilioLib.new

    WebuiCallerSession.where("endtime is not NULL and tCallSegmentSid is NULL and (tStatus is NULL or tStatus = 'completed') ").limit(100).each do |session|
        if !session.sid.nil? && !session.sid.starts_with?("CA")
          session.tEndTime = session.endtime
          session.tStartTime = session.starttime
          session.tPrice = 0.0
          caller_sessions << session.attributes
        else
          caller_sessions << twillio_lib.update_twilio_stats_by_model(session).attributes
        end
    end

    WebuiCallerSession.import_hashes caller_sessions

    caller_sessions = []
    twillio_lib = TwilioLib.new

    PhonesOnlyCallerSession.where("endtime is not NULL and tCallSegmentSid is NULL and (tStatus is NULL or tStatus = 'completed') ").limit(100).each do |session|
      if !session.sid.nil? && !session.sid.starts_with?("CA")
        session.tEndTime = session.endtime
        session.tStartTime = session.starttime
        session.tPrice = 0.0
        caller_sessions << session.attributes
      else
        caller_sessions << twillio_lib.update_twilio_stats_by_model(session).attributes
      end
    end
    PhonesOnlyCallerSession.import_hashes caller_sessions
  end
end
