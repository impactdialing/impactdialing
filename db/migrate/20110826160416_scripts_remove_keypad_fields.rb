class ScriptsRemoveKeypadFields < ActiveRecord::Migration
  def self.up
    (50..99).each{|i|
      remove_column :scripts, "keypad_#{i}"
    }

  end

  def self.down
    (50..99).each{|i|
      add_column :scripts, "keypad_#{i}", :string
    }
  end
end