class Answer < ActiveRecord::Base
  belongs_to :voter
  belongs_to :question
  belongs_to :possible_response

  scope :for, lambda{|question| where("question_id = #{question.id}")}
end
