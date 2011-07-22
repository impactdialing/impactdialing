class ChangeRecordingToPaperclip < ActiveRecord::Migration
  def self.up
    add_column :recordings, :file_file_name, :string
    add_column :recordings, :file_content_type, :string
    add_column :recordings, :file_file_size, :string
    add_column :recordings, :file_updated_at, :datetime
    Recording.reset_column_information
    Recording.all.each do |recording|
      recording.update_attributes(:file_file_name => recording.recording_url.split('/').last, :file_updated_at => Time.now) unless recording.recording_url.blank?
    end
    remove_column :recordings, :recording_url
  end

  def self.down
    add_column :recordings, :recording_url, :string
    Recording.reset_column_information
    Recording.all.each do |recording|
      recording.update_attribute(:recording_url, "http://s3.amazonaws.com/impactdialingapp/#{Rails.env}/uploads/#{recording.user_id}/#{recording.file_file_name}")
    end
    remove_column :recordings, :file_updated_at
    remove_column :recordings, :file_file_size
    remove_column :recordings, :file_content_type
    remove_column :recordings, :file_file_name
  end
end
