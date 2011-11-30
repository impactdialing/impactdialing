class AddCallRecordingFields < ActiveRecord::Migration
  def self.up
    add_column :accounts, :record_calls, :boolean, :default=>false
    add_column :call_attempts, :recording_url, :string
    add_column :call_attempts, :recording_duration, :integer
  end

  def self.down
    remove_column :call_attempts, :recording_duration
    remove_column :call_attempts, :recording_url
    remove_column :accounts, :record_calls
  end
end