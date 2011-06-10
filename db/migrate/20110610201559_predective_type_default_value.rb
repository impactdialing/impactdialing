class PredectiveTypeDefaultValue < ActiveRecord::Migration
  def self.up
    change_column :campaigns, :predective_type, :string, :default => 'preview'
  end

  def self.down
    change_column :campaigns, :predective_type, :string
  end
end
