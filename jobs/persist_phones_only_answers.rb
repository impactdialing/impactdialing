require 'resque-loner'

class PersistPhonesOnlyAnswers
    include Resque::Plugins::UniqueJob
    @queue = :persist_jobs
    
    def self.perform
      answers = []
      answers_list = multipop(RedisPhonesOnlyAnswer.phones_only_answers_list, 100).sort_by{|a| a['voter_id']}
      answers_list.each do |answer_list|
        voter = Voter.find(answer_list['voter_id'])
        caller_session = CallerSession.find(answer_list['caller_session_id'])
        question = Question.find(answer_list['question_id'])
        answers << voter.answer(question, answer_list['digit'], caller_session)        
      end
      Answer.import answers      
    end
    
    def self.multipop(list, num)
      result = []
      num.times do |x|
        element = list.shift
        result << JSON.parse(element) unless element.nil?
      end
      result
    end
    
end