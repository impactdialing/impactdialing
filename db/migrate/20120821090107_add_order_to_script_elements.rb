class AddOrderToScriptElements < ActiveRecord::Migration
  def self.up
    add_column(:script_texts, :script_order, :integer)
    add_column(:questions, :script_order, :integer)
    add_column(:notes, :script_order, :integer)
  end

  def self.down
    remove_column(:script_texts, :script_order, :integer)
    remove_column(:questions, :script_order, :integer)
    remove_column(:notes, :script_order, :integer)    
  end
end
