class PossibleResponse < ActiveRecord::Base
  belongs_to :question
  has_many :answers
  
  def stats(from_date, to_date, total_answers, campaign_id)
    number_of_answers = answers.within(from_date, to_date).with_campaign_id(campaign_id).size
    {answer: value, number: number_of_answers, percentage:  total_answers == 0 ? 0 : (number_of_answers * 100 / total_answers)}
  end
  
end
