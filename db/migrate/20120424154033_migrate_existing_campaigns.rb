class MigrateExistingCampaigns < ActiveRecord::Migration
  def self.up
    Campaign.connection.execute("update campaigns set type = 'Robo' where type = 'preview' and robo = true");
    Campaign.connection.execute("update campaigns set type = 'Preview' where type = 'preview' and robo = false");
    Campaign.connection.execute("update campaigns set type = 'Progressive' where type = 'progressive'");
    Campaign.connection.execute("update campaigns set type = 'Predictive' where type = 'algorithm1'");
  end

  def self.down
  end
end
