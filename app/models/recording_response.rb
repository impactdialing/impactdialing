class RecordingResponse < ActiveRecord::Base
  belongs_to :recording
  validates_presence_of :response, :message => "Please specify a response"
  validates_presence_of :keypad, :message => "Please specify a keypad value"
  validates_uniqueness_of :keypad, :scope => :recording_id, :message=>"Recording must have unique keypad response."
end
