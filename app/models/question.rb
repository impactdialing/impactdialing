class Question < ActiveRecord::Base
  validates_presence_of :text
  belongs_to :script
  has_many :possible_responses
  has_many :answers
  accepts_nested_attributes_for :possible_responses, :allow_destroy => true
end
