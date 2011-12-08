class Question < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  validates_presence_of :text
  belongs_to :script
  has_many :possible_responses
  has_many :answers
  accepts_nested_attributes_for :possible_responses, :allow_destroy => true
  scope :answered_by, lambda { |voter| joins(:answers).where("answers.voter_id = ?", voter.id) }
  scope :not_answered_by, lambda { |voter| order("id ASC").where("questions.id not in (?)", Question.answered_by(voter).collect(&:id) + [-1]) }

  def stats(from_date, to_date)
    question.possible_responses.collect { |possible_response| possible_response.stats(from_date, to_date) }
  end

  def answered_within(from_date, to_date)
    answers.within(from_date, to_date)
  end

  def read(call_attempt)
    Twilio::Verb.new do |v|
      v.gather(:timeout => 5, :action => gather_response_call_attempt_url(call_attempt, :question_id => self, :host => Settings.host, :port => Settings.port), :method => "POST") do
        v.say self.text
        possible_responses.each do |response|
          v.say "press #{response.keypad} for #{response.value}"
        end
      end
      v.redirect(gather_response_call_attempt_url(call_attempt, :question_id =>id, :host => Settings.host, :port => Settings.port), :method => "POST")
    end.response
  end

end
