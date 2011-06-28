class EditRecording < ActiveRecord::Migration
  def self.up
    Recording.destroy_all
    remove_column :recordings, :user_id
    remove_column :recordings, :recording_url
    add_column :recordings, :file_file_name,    :string
    add_column :recordings, :file_content_type, :string
    add_column :recordings, :file_file_size,    :integer
    add_column :recordings, :file_updated_at,   :datetime
    add_column :recordings, :script_id, :integer
  end

  def self.down
    add_column :recordings, :user_id, :integer
    add_column :recordings, :recording_url, :string
    remove_column :recordings, :file_file_name
    remove_column :recordings, :file_content_type
    remove_column :recordings, :file_file_size
    remove_column :recordings, :file_updated_at
    remove_column :recordings, :script_id
  end
end
