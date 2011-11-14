class CreateNoteResponse < ActiveRecord::Migration
  def self.up
    create_table :note_responses do |t|
      t.column :voter_id, :integer, :null => false
      t.column :note_id, :integer, :null => false
      t.column :response, :string
    end
    
  end

  def self.down
    drop_table :note_responses
  end
end

