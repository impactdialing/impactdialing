class AddBestWrapupTimeToSimulatedValues < ActiveRecord::Migration
  def self.up
    add_column :simulated_values, :best_wrapup_time, :float
  end

  def self.down
    remove_column :simulated_values, :best_wrapup_time
  end
end
