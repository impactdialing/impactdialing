class ScriptAddMoreResults < ActiveRecord::Migration
  def self.up
    add_column :scripts, :result_set_11, :text
    add_column :scripts, :result_set_12, :text
    add_column :scripts, :result_set_13, :text
    add_column :scripts, :result_set_14, :text
    add_column :scripts, :result_set_15, :text
    add_column :scripts, :result_set_16, :text
    add_column :scripts, :note_11, :string
    add_column :scripts, :note_12, :string
    add_column :scripts, :note_13, :string
    add_column :scripts, :note_14, :string
    add_column :scripts, :note_15, :string
    add_column :scripts, :note_16, :string
  end

  def self.down
    remove_column :scripts, :result_set_11
    remove_column :scripts, :result_set_12
    remove_column :scripts, :result_set_13
    remove_column :scripts, :result_set_14
    remove_column :scripts, :result_set_15
    remove_column :scripts, :result_set_16
    remove_column :scripts, :note_11
    remove_column :scripts, :note_12
    remove_column :scripts, :note_13
    remove_column :scripts, :note_14
    remove_column :scripts, :note_15
    remove_column :scripts, :note_16
  end
end