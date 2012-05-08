class Question < ActiveRecord::Base
  include Rails.application.routes.url_helpers
  validates_presence_of :text
  belongs_to :script
  has_many :possible_responses
  has_many :answers
  before_destroy :not_already_answered?
  accepts_nested_attributes_for :possible_responses, :allow_destroy => true
  scope :answered_by, lambda { |voter| joins(:answers).where("answers.voter_id = ?", voter.id) }
  scope :not_answered_by, lambda { |voter| order("id ASC").where("questions.id not in (?)", Question.answered_by(voter).collect(&:id) + [-1]) }

  def stats(from_date, to_date)
    question.possible_responses.collect { |possible_response| possible_response.stats(from_date, to_date) }
  end

  def answered_within(from_date, to_date, campaign_id)
    answers.within(from_date, to_date).with_campaign_id(campaign_id)
  end
  
  def not_already_answered?
    script.errors.add(:base, "You cannot delete questions that have already been answered.") if answers.count > 0
    errors.blank?
  end

  def read(caller_session)
    Twilio::Verb.new do |v|
      v.gather(:timeout => 5, :finishOnKey=>"*", :action => gather_response_caller_url(caller_session.caller, :session_id => caller_session.id, :question_id => self, :host => Settings.host, :port => Settings.port), :method => "POST") do
        v.say self.text
        possible_responses.each do |response|
          v.say "press #{response.keypad} for #{response.value}" unless (response.value == "[No response]")
        end
        v.say I18n.t(:submit_results)
      end
      v.redirect(gather_response_caller_url(caller_session.caller, :session_id => caller_session.id, :question_id =>id, :host => Settings.host, :port => Settings.port), :method => "POST")
    end.response
  end

end
