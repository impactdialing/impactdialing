class CreateSimulatedValues < ActiveRecord::Migration
  def self.up
    create_table :simulated_values do |t|
      t.integer :campaign_id
      t.float :alpha
      t.float :beta

      t.timestamps
    end
  end

  def self.down
    drop_table :simulated_values
  end
end
