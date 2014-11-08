require 'resque-loner'
require 'librato_resque'

##
# Run periodically to persist answer data from phones-only callers.
#
# ### Metrics
#
# - completed
# - failed
# - timing
# - sql timing
#
# ### Monitoring
#
# Alert conditions:
#
# - 1 failure (WARNING: Exception rescued)
# - stops reporting for 5 minutes
#
class PersistPhonesOnlyAnswers
  include Resque::Plugins::UniqueJob
  extend LibratoResque

  @queue = :persist_jobs

  def self.perform
    lists = []
    answers_list = multipop($redis_phones_ans_uri_connection, 'phones_only_answer_list', 4000).sort_by{|a| a['voter_id']}
    answers_list.each do |answer_list|
      begin
        voter = Voter.find(answer_list['voter_id'])
        caller_session = CallerSession.find(answer_list['caller_session_id'])
        question = Question.find(answer_list['question_id'])
        lists << voter.answer(question, answer_list['digit'], caller_session)
      rescue Exception => e
        Rails.logger.error("#{self} Exception: #{e.class}: #{e.message}")
        Rails.logger.error("#{self} Exception Backtrace: #{e.backtrace}")
      end
    end

    Answer.import lists.compact
  end

  def self.multipop(connection, list_name, num)
    num_of_elements = connection.llen list_name
    num_to_pop = num_of_elements < num ? num_of_elements : num
    result = []
    num_to_pop.times do |x|
      element = connection.rpop list_name
      result << JSON.parse(element) unless element.nil?
    end
    result
  end
end