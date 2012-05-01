class VoterObserver < ActiveRecord::Observer

  def answer_recorded(voter)
    return unless voter.unanswered_questions.blank?
    return unless voter.answer_recorded_by

    voter.current_call_attempt.try(:update_attributes, {:wrapup_time => Time.now})

  end
end
