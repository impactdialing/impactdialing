class Question < ActiveRecord::Base
  include Rails.application.routes.url_helpers

  attr_accessible :text, :script_id, :script_order, :possible_responses_attributes, :external_id_field

  validates :text, presence: true
  validates :script, presence: true
  validates :script_order, presence:true, numericality: true

  belongs_to :script, :inverse_of => :questions
  has_many :possible_responses, :inverse_of => :question
  has_many :answers
  accepts_nested_attributes_for :possible_responses, :allow_destroy => true
  scope :answered_by, lambda { |voter| joins(:answers).where("answers.voter_id = ?", voter.id) }
  scope :not_answered_by, lambda { |voter| order("id ASC").where("questions.id not in (?)", Question.answered_by(voter).collect(&:id) + [-1]) }
  default_scope :order => "script_order"

  def stats(from_date, to_date)
    question.possible_responses.collect { |possible_response| possible_response.stats(from_date, to_date) }
  end

  def answered_within(from_date, to_date, campaign_id)
    answers.within(from_date, to_date).with_campaign_id(campaign_id)
  end

  def self.question_count_script(script_id)
    questions = Question.select("id").where("script_id = ?",script_id)
    Answer.select("question_id").where("question_id in (?)",questions).group("question_id").count
  end

  def answered?
    true
  end

  def delete_question?
    if script.questions.size == 1
      return {response: 'error', message: 'Yo Yp'}
    end
  end


  def self.question_texts(question_ids)
    texts = []
    questions = Question.select("id, text").where("id in (?)",question_ids).order('id')
    question_ids.each_with_index do |question_id, index|
      unless questions.collect{|x| x.id}.include?(question_id)
        texts << ""
      else
        texts << questions.detect{|at| at.id == question_id}.text
      end
    end
    texts
  end

  def as_json(options)
    {id: id, text: text, script_order: script_order, possible_responses: possible_responses}

  end
end
