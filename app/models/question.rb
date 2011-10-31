class Question < ActiveRecord::Base
  validates_presence_of :text
  belongs_to :script
  has_many :possible_responses
  accepts_nested_attributes_for :possible_responses, :allow_destroy => true
end
