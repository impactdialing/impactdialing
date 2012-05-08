class Robo < Campaign
  
  def leave_voicemail?
     voicemail_script
  end
  
  def dial
    update_attribute(:calls_in_progress, true)
    dial_voters
    update_attribute(:calls_in_progress, false)
  end
  
  
  def start(user)
    return false if calls_in_progress? or (not account.activated?)
    return false if script.robo_recordings.size == 0
    Delayed::Job.enqueue BroadcastCampaignJob.new(self.id)
    UserMailer.new.notify_broadcast_start(self,user) if Rails.env == 'heroku'
    update_attribute(:calls_in_progress, true)
  end
  
  def voters_dialed
      call_attempts.count('voter_id', :distinct => true)
  end
  
  def voters_remaining
     all_voters.count - voters_dialed
   end
  
  def stop
    Delayed::Job.all do |job|
        if job.name == "Broadcastcampaign-job-#{self.id}"
          job.delete
        end
    end
    update_attribute(:calls_in_progress, false)
  end
  
  def answer_results(from_date, to_date)
    result = Hash.new
    unless script.nil?
      script.robo_recordings.each do |robo_recording|
        total_answers = robo_recording.answered_within(from_date, to_date, self.id).size
        result[robo_recording.name] = robo_recording.recording_responses.collect { |recording_response| recording_response.stats(from_date, to_date, total_answers, self.id) }
        result[robo_recording.name] << {answer: "[No response]", number: 0, percentage:  0} unless robo_recording.recording_responses.find_by_response("[No response]").present?
      end
    end
    result
  end
  
  private
  def dial_voters
    self.voter_lists.each do |voter_list|
      return unless self.calls_in_progress?
      voter_list.dial if voter_list.enabled
    end
  end
  
  
  
end