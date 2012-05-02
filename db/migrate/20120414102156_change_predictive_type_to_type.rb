class ChangePredictiveTypeToType < ActiveRecord::Migration
  def self.up
    rename_column :campaigns, :predictive_type, :type
  end

  def self.down
    rename_column :campaigns, :type, :predictive_type
  end
end
