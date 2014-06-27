class AddRecordingIdAndRecordingDeliveredManuallyToCallAttempt < ActiveRecord::Migration
  def change
    add_column :call_attempts, :recording_id, :integer
    add_column :call_attempts, :recording_delivered_manually, :boolean, default: false
  end
end
