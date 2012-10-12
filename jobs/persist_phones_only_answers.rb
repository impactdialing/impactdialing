require 'resque-loner'

class PersistPhonesOnlyAnswers
    include Resque::Plugins::UniqueJob
    @queue = :persist_jobs
    
    def self.perform
      lists = []
      answers_list = multipop($redis_phones_ans_uri_connection, 'phones_only_answer_list', 100).sort_by{|a| a['voter_id']}
      answers_list.each do |answer_list|
        voter = Voter.find(answer_list['voter_id'])
        caller_session = CallerSession.find(answer_list['caller_session_id'])
        question = Question.find(answer_list['question_id'])
        lists << voter.answer(question, answer_list['digit'], caller_session)        
      end
      Answer.import lists.compact      
    end
    
    def self.multipop(connection, list_name, num)
      result = []
      num.times do |x|
        element = connection.rpop list_name
        result << JSON.parse(element) unless element.nil?
      end
      result
    end
    
end