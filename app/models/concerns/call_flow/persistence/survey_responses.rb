class CallFlow::Persistence::SurveyResponses < CallFlow::Persistence
private
  def questions
    data = call_data[:questions].blank? ? '{}' : call_data[:questions]
    @questions ||= JSON.parse(data)
  end

  def notes
    data = call_data[:notes].blank? ?  '{}' : call_data[:notes]
    @notes ||= JSON.parse(data)
  end

  def possible_responses_that_retry
    @possible_responses_that_retry ||= PossibleResponse.where(id: questions.values, retry: true)
  end

public
  def save(voter_record, call_attempt_record)
    save_answers(voter_record, call_attempt_record)
    save_notes(voter_record, call_attempt_record)
  end

  def complete_lead?
    possible_responses_that_retry.count.zero?
  end

  def save_answers(voter_record, call_attempt_record)
    questions.each do |question_id, possible_response_id|
      next unless question_id.present? and possible_response_id.present?
      Answer.create!({
        voter_id: voter_record.id,
        caller_id: caller_session.caller_id,
        call_attempt_id: call_attempt_record.id,
        campaign_id: campaign.id,
        possible_response_id: possible_response_id,
        question_id: question_id
      })
    end
  end

  def save_notes(voter_record, call_attempt_record)
    notes.each do |note_id, note_text|
      next unless note_id.present? and note_text.present?
      NoteResponse.create!({
        voter_id: voter_record.id,
        call_attempt_id: call_attempt_record.id,
        campaign_id: campaign.id,
        response: note_text,
        note_id: note_id
      })
    end
  end
end

