class ScriptAddResultGroups < ActiveRecord::Migration
  def self.up
    add_column :scripts, :result_set_1, :text
    add_column :scripts, :result_set_2, :text
    add_column :scripts, :result_set_3, :text
    add_column :scripts, :result_set_4, :text
    add_column :scripts, :result_set_5, :text
    add_column :scripts, :result_set_6, :text
    add_column :scripts, :result_set_7, :text
    add_column :scripts, :result_set_8, :text
    add_column :scripts, :result_set_9, :text
    add_column :scripts, :result_set_10, :text
    add_column :scripts, :note_1, :string
    add_column :scripts, :note_2, :string
    add_column :scripts, :note_3, :string
    add_column :scripts, :note_4, :string
    add_column :scripts, :note_5, :string
    add_column :scripts, :note_6, :string
    add_column :scripts, :note_7, :string
    add_column :scripts, :note_8, :string
    add_column :scripts, :note_9, :string
    add_column :scripts, :note_10, :string
  end

  def self.down
    remove_column :scripts, :note_1
    remove_column :scripts, :note_2
    remove_column :scripts, :note_3
    remove_column :scripts, :note_4
    remove_column :scripts, :note_5
    remove_column :scripts, :note_6
    remove_column :scripts, :note_7
    remove_column :scripts, :note_8
    remove_column :scripts, :note_9
    remove_column :scripts, :note_10
    remove_column :scripts, :result_set_1
    remove_column :scripts, :result_set_2
    remove_column :scripts, :result_set_3
    remove_column :scripts, :result_set_4
    remove_column :scripts, :result_set_5
    remove_column :scripts, :result_set_6
    remove_column :scripts, :result_set_7
    remove_column :scripts, :result_set_8
    remove_column :scripts, :result_set_9
    remove_column :scripts, :result_set_10
  end
end