class CallStats::SurveyResponses
  attr_reader :campaign, :from_date, :to_date

private
  def transfer_attempts
    CallStats.transfer_attempts(campaign)
  end

public
  def initialize(campaign, options)
    @campaign  = campaign
    @from_date = options['from_date']
    @to_date   = options['to_date']
  end

  def transfers(from_date, to_date)
    # result = {}
    # attempts = transfer_attempts.within(from_date, to_date, id)
    # unless attempts.blank?
    #   result = TransferAttempt.aggregate(attempts)
    # end
    # result
  end

  def answers
    # load question ids related to the campaign, from answers
    # question_ids = Answer.where(campaign_id: campaign.id).uniq.pluck(:question_id)
    # answer_count = Answer.select("possible_response_id").from('answers use index (index_answers_on_campaign_created_at_possible_response)').
    #     where("campaign_id = ?", campaign.id).within(from_date, to_date).group("possible_response_id").count
    # total_answers = Answer.where("campaign_id = ?",campaign.id).within(from_date, to_date).group("question_id").count
    # questions_data = Question.where(id: question_ids).includes(:possible_responses).each_with_object({}) do |question, memo|
    #   memo[question.script_id] ||= []
    #   memo[question.script_id] << question
    # end
    # Script.where(id: questions_data.keys).each_with_object({}) do |script, result|
    #   result[script.id] = {script: script.name, questions: {}}
    #   questions_data[script.id].each do |question|
    #     result[script.id][:questions][question.text] = question.possible_responses.collect { |possible_response| possible_response.stats(answer_count, total_answers) }
    #     result[script.id][:questions][question.text] << {answer: "[No response]", number: 0, percentage:  0} unless question.possible_responses.select { |x| x.value == "[No response]"}.any?
    #   end
    # end
  end
end