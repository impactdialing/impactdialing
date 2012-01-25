class RecordingResponse < ActiveRecord::Base
  
  has_many :call_responses
  belongs_to :robo_recording
  
  validates_presence_of :response, :message => "Each response must have a label."
  validates_presence_of :keypad, :message => "Each response must have a keypad number."
  validates_uniqueness_of :keypad, :scope => :robo_recording_id, :message=>"For each recording, you can only use each keypad number once."
  
  def stats(from_date, to_date, total_answered_voters, campaign_id)
    number_of_answers = call_responses.within(from_date, to_date, campaign_id).size
    {answer: response, number: number_of_answers, percentage:  total_answered_voters == 0 ? 0 : (number_of_answers * 100 / total_answered_voters)}
  end
  
end