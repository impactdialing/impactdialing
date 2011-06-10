class RenamePredictiveTypeInCampaign < ActiveRecord::Migration
  def self.up
    rename_column :campaigns, :predective_type, :predictive_type
  end

  def self.down
    rename_column :campaigns, :predictive_type, :predective_type
  end
end
