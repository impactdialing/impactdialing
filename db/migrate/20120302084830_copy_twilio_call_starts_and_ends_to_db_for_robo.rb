class CopyTwilioCallStartsAndEndsToDbForRobo < ActiveRecord::Migration
  def self.up
    CallAttempt.connection.execute("update call_attempts set connecttime = tStartTime and call_end = tEndTime where connecttime is null and call_end is null and campaign_id in (select id from campaigns where robo = true)");
  end

  def self.down
    CallAttempt.connection.execute("update call_attempts set connecttime = null and call_end = null where connecttime is not null and call_end is not null and campaign_id in (select id from campaigns where robo = true)");
  end
end
