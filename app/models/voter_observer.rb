class VoterObserver < ActiveRecord::Observer

  def answer_recorded(voter)
    return unless voter.unanswered_questions.blank?
    return unless voter.last_call_attempt
    voter.last_call_attempt.caller_session.try(:publish,"voter_push",voter.campaign.next_voter_in_dial_queue(voter).try(:info)||{})
  end
end
