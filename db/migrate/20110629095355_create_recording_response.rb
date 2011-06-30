class CreateRecordingResponse < ActiveRecord::Migration
  def self.up
    create_table :recording_responses do |t|
      t.integer :robo_recording_id
      t.string :response
      t.integer :keypad
    end
  end

  def self.down
    drop_table :recording_responses
  end
end
