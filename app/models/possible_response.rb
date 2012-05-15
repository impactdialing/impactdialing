class PossibleResponse < ActiveRecord::Base
  belongs_to :question
  has_many :answers
  
  def stats(answer_count, total_count)
    number_of_answers = answer_count[self.id] || 0
    total_answers = total_count[question_id] || 1
    {answer: value, number: number_of_answers, percentage:  total_answers == 0 ? 0 : (number_of_answers * 100 / total_answers)}
  end
  
  def answered?
    answers.first != nil
  end
  
  def self.possible_response_count(questions)
    possible_responses = PossibleResponse.select("id").where("question_id in (?)",questions)
    Answer.select("possible_response_id").where("possible_response_id in (?)",possible_responses).group("possible_response_id").count
  end
      
end
