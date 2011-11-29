class Answer < ActiveRecord::Base
  belongs_to :voter
  belongs_to :question
  belongs_to :possible_response

  scope :for, lambda{|question| where("question_id = #{question.id}")}
  scope :answered_within, lambda { |from, to| where(:created_at => from..(to + 1.day))}
end
