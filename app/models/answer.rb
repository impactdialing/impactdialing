class Answer < ActiveRecord::Base
  belongs_to :voter
  belongs_to :question
  belongs_to :possible_response
  belongs_to :campaign

  scope :for, lambda{|question| where("question_id = #{question.id}")}
  scope :within, lambda { |from, to, campaign_id| where(:created_at => from..(to + 1.day)).where(campaign_id: campaign_id)}
  scope :belong_to, lambda { |campaign_voters| where(:voter_id => campaign_voters)}
  
  
end
