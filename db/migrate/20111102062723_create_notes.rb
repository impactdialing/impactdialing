class CreateNotes < ActiveRecord::Migration
  def self.up
    create_table :notes do |t|
      t.column :note, :text, :null => false
      t.column :script_id, :integer, :null => false
    end
  end

  def self.down
    drop_table :notes
  end
end
