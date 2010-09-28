class CreateRecordings < ActiveRecord::Migration
  def self.up
    create_table :recordings, :force => true do |t|
      t.integer :user_id
      t.string :recording_url
      t.integer :active, :default=>true
      t.string :name
      t.timestamps
    end
    add_column :campaigns, :recording_id, :integer
    add_column :campaigns, :use_recordings, :boolean, :default=>false
  end

  def self.down
    remove_column :campaigns, :use_recordings
    remove_column :campaigns, :recording_id
    drop_table :recordings
  end
end
