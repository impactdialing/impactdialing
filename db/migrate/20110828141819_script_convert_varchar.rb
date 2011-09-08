class ScriptConvertVarchar < ActiveRecord::Migration
  def self.up
    change_column :scripts, :result_set_11, :string
    change_column :scripts, :result_set_12, :string
    change_column :scripts, :result_set_13, :string
    change_column :scripts, :result_set_14, :string
    change_column :scripts, :result_set_15, :string
    change_column :scripts, :result_set_16, :string
  end

  def self.down
    change_column :scripts, :result_set_11, :text
    change_column :scripts, :result_set_12, :text
    change_column :scripts, :result_set_13, :text
    change_column :scripts, :result_set_14, :text
    change_column :scripts, :result_set_15, :text
    change_column :scripts, :result_set_16, :text
  end
end
