class MigrateExistingAnswersToTheRightCampaign < ActiveRecord::Migration
  def self.up
    Answer.connection.execute("update answers set campaign_id = (select campaign_id from voters where answers.voter_id = voters.id)");
  end

  def self.down
    Answer.connection.execute("update answers set campaign_id = NULL");
  end
end
