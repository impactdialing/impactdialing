class AddCompositeIndexesToVotersForReportsDials < ActiveRecord::Migration
  def self.up
    add_index(:voters, [:campaign_id,:status, :id])
  end

  def self.down
  end
end
