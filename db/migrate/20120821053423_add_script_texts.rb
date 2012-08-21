class AddScriptTexts < ActiveRecord::Migration
  def self.up
    create_table :script_texts do |t|
      t.integer :script_id
      t.text :section
    end
    
  end

  def self.down
    drop_table :script_texts
  end
end
