class Question < ActiveRecord::Base
  validates_presence_of :text
  belongs_to :script
  has_many :possible_responses
  has_many :answers
  accepts_nested_attributes_for :possible_responses, :allow_destroy => true
  
  def stats(from_date, to_date)
    question.possible_responses.collect { |possible_response| possible_response.stats(from_date, to_date)}    
  end
end
