shared_examples_for 'any answer report' do
  context 'answer stats' do
    scenario 'display number & percentage responses of each type given for each question' do
      visit target_url
      expect(page).to have_content page_title

      question_ids = Answer.select('question_id').pluck(:question_id)
      i            = 1
      Question.where(id: question_ids).includes(:possible_responses).each do |question|
        expect(page).to have_content("Script: #{question.script.name}")
        expect(page).to have_content("Question #{i}: #{question.text}")
        within("table:nth-of-type(#{i})") do
          question.possible_responses.each do |possible_response|
            answers        = answers_query
            next if answers.count.zero?

            answer_count   = answers.group('possible_response_id').count
            answer_total   = answers.group('question_id').count
            answer_perc    = (answer_count[possible_response.id].try(:*, 100) || 0) / answer_total[question.id]
            expected_count = answer_count[possible_response.id] || 0
            expected_perc  = "#{answer_perc} %"

            expect(page).to have_content possible_response.value
            expect(page).to have_content expected_count
            expect(page).to have_content expected_perc
          end
        end
        i += 1
      end

      expect(i > 1).to be_truthy
    end
  end
end
