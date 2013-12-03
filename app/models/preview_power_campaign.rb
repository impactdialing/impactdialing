module PreviewPowerCampaign

  def next_voter_in_dial_queue(current_voter_id = nil)
    begin
      voter = all_voters.next_in_priority_or_scheduled_queues(blocked_numbers).first
      voter ||= all_voters.next_in_recycled_queue(recycle_rate, blocked_numbers, current_voter_id).first

      update_voter_status_to_ready(voter)
    rescue ActiveRecord::StaleObjectError
      retry
    end
    return voter
  end

  def update_voter_status_to_ready(voter)
    voter.update_attributes(status: CallAttempt::Status::READY) unless voter.nil?
  end


  def caller_conference_started_event(current_voter_id)
    next_voter = next_voter_in_dial_queue(current_voter_id)
    {event: 'conference_started', data: next_voter.nil? ? {campaign_out_of_leads: true} : next_voter.info}
  end

  def voter_connected_event(call)
    {event: 'voter_connected', data: {call_id:  call.id}}
  end

  def call_answered_machine_event(call_attempt)
    next_voter = next_voter_in_dial_queue(call_attempt.voter.id)
    {event: 'dial_next_voter', data: next_voter.nil? ? {} : next_voter.info}
  end



end