class AddBestValuesToSimulation < ActiveRecord::Migration
  def self.up
    remove_column :simulated_values, :alpha
    remove_column :simulated_values, :beta
    add_column :simulated_values, :best_dials, :float
    add_column :simulated_values, :best_conversation, :float
    add_column :simulated_values, :longest_conversation, :float
  end

  def self.down
    add_column :simulated_values, :alpha, :float
    add_column :simulated_values, :beta, :float
    remove_column :simulated_values, :best_dials
    remove_column :simulated_values, :best_conversation
    remove_column :simulated_values, :longest_conversation
  end
end
