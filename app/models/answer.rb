class Answer < ActiveRecord::Base
  belongs_to :voter
  belongs_to :caller
  belongs_to :question
  belongs_to :possible_response
  belongs_to :campaign

  scope :for, lambda{|question| where("question_id = #{question.id}")}
  scope :within, lambda { |from, to| where(:created_at => from..(to + 1.day)) }
  scope :belong_to, lambda { |campaign_voters| where(:voter_id => campaign_voters)}
  scope :for_campaign, lambda { |campaign| where(:campaign_id => campaign.id) }
end
