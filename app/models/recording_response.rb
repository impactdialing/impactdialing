class RecordingResponse < ActiveRecord::Base
  belongs_to :robo_recording
  validates_presence_of :response, :message => "Each response must have a label."
  validates_presence_of :keypad, :message => "Each response must have a keypad number."
  validates_uniqueness_of :keypad, :scope => :robo_recording_id, :message=>"For each recording, you can only use each keypad number once."
end