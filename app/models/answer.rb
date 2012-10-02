class Answer < ActiveRecord::Base
  belongs_to :voter
  belongs_to :caller
  belongs_to :question
  belongs_to :possible_response
  belongs_to :campaign
  belongs_to :call_attempt

  scope :for, lambda{|question| where("question_id = #{question.id}")}
  scope :for_questions, lambda{|question_ids| where("question_id in (?) ", question_ids)}
  scope :within, lambda { |from, to| where(:created_at => from..to) }
  scope :with_campaign_id, lambda { |campaign_id| where(:campaign_id => campaign_id) }
  
  def self.question_ids(cam_id)
    Answer.where(campaign_id: cam_id).order(:question_id).uniq.pluck(:question_id)
  end
  
end
