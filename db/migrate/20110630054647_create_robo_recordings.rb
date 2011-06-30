class CreateRoboRecordings < ActiveRecord::Migration
  def self.up
    create_table :robo_recordings do |t|
      t.column :script_id,  :integer
      t.column :name,  :string
      t.column :file_file_name, :string
      t.column :file_content_type,  :string
      t.column :file_file_size, :integer
      t.column :file_updated_at,   :datetime
    end
  end

  def self.down
    drop_table :robo_recordings
  end
end
