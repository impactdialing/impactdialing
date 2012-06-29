class AddIndexesForGroupByStatus < ActiveRecord::Migration
  def self.up
    add_index(:voters, [:campaign_id,:status])
  end

  def self.down
  end
end
