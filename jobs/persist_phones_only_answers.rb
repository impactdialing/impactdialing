require 'resque-loner'

class PersistPhonesOnlyAnswers
    include Resque::Plugins::UniqueJob
    @queue = :persist_jobs_phones_only
    
    def self.perform
      lists = []
      answers_list = multipop($redis_phones_ans_uri_connection, 'phones_only_answer_list', 2000).sort_by{|a| a['voter_id']}
      answers_list.each do |answer_list|
        begin
          voter = Voter.find(answer_list['voter_id'])
          caller_session = CallerSession.find(answer_list['caller_session_id'])
          question = Question.find(answer_list['question_id'])
          lists << voter.answer(question, answer_list['digit'], caller_session)        
        rescue Exception
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