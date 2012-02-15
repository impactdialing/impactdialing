class CopyTwilioStatsToDatabaseStatsForCallerSession < ActiveRecord::Migration
  def self.up
    CallerSession.connection.execute("update caller_sessions set starttime = tStartTime");
    CallerSession.connection.execute("update caller_sessions set endtime = tEndTime where endtime is null");
  end

  def self.down
    CallerSession.connection.execute("update caller_sessions set starttime = NULL");
  end
end
