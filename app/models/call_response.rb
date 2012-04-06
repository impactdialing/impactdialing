class CallResponse < ActiveRecord::Base
  belongs_to :robo_recording
  belongs_to :recording_response
  belongs_to :call_attempt
  belongs_to :campaign
  
  scope :within, lambda { |from, to, campaign_id| where(:created_at => from..to).where(campaign_id: campaign_id)}
  
  validates_uniqueness_of :call_attempt_id, :scope => :robo_recording_id

  def self.log_response(call_attempt, robo_recording, response)
    recording_response = robo_recording.response_for(response)
    call_response = call_attempt.call_responses.where(:robo_recording_id => robo_recording.id).first
    call_response ||= call_attempt.call_responses.create!(:response => response, :recording_response => recording_response, :robo_recording => robo_recording, :campaign => call_attempt.campaign)
    call_response.update_attributes(:times_attempted => call_response.times_attempted + 1, :recording_response => recording_response)
    call_response
  end
end
