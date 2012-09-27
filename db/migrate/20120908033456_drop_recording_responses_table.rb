class DropRecordingResponsesTable < ActiveRecord::Migration
  def change
    drop_table :recording_responses
  end
end
