class CopyTwilioStatsforRoboCampaignsPartial < ActiveRecord::Migration
  def self.up
         CallAttempt.connection.execute("update call_attempts set connecttime = tStartTime , call_end = tEndTime where campaign_id in (select id from campaigns where robo = true)");
  end

  def self.down
     CallAttempt.connection.execute("update call_attempts set connecttime = null , call_end = null where  campaign_id in (select id from campaigns where robo = true)");
  end
end
