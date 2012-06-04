class DialReport
  
  def compute_campaign_report(campaign, from_date, to_date)
    @from_date = from_date
    @to_date = to_date
    @campaign = campaign
    @leads_grouped_by_status = @campaign.all_voters.group("status").count
    @leads_grouped_by_status_filtered = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).group("status").count
    overview_summary
    per_lead_dials
    @lead_dials = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).group("status").count
  end
  
  def dialed_and_completed
    sanitize_dials(@leads_grouped_by_status[CallAttempt::Status::SUCCESS]) + sanitize_dials(@leads_grouped_by_status[CallAttempt::Status::FAILED])
  end
  
  def scheduled_for_now
    @campaign.all_voters.scheduled.count
  end
  
  def leads_available_for_retry
    @leads_available_retry = sanitize_dials(@campaign.all_voters.enabled.avialable_to_be_retried(@campaign.recycle_rate).count + scheduled_for_now + 
    @campaign.all_voters.by_status(CallAttempt::Status::ABANDONED).count)
  end
  
  def leads_not_available_for_retry
    @leads_not_available_for_retry = sanitize_dials((sanitize_dials(@leads_grouped_by_status[CallAttempt::Status::SCHEDULED]) - scheduled_for_now) + @campaign.all_voters.enabled.not_avialable_to_be_retried(@campaign.recycle_rate).count)
  end
  
  def leads_not_dialed
    sanitize_dials(@leads_grouped_by_status['not called']) + sanitize_dials(@leads_grouped_by_status[CallAttempt::Status::RINGING]) + sanitize_dials(@leads_grouped_by_status[CallAttempt::Status::READY])
  end
  
  def overview_summary
   leads_available_for_retry
   leads_not_available_for_retry
   @total_summary = dialed_and_completed + leads_not_dialed + @leads_not_available_for_retry + @leads_available_retry  
  end
  
  def leads_grouped_by_status_filtered
    @leads_grouped_by_status_filtered
  end
  
  def per_lead_dials      
    # @total_voters_count = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).count         
    # @total_lead_dials = ((@total_voters_count == 0) ? 1 : @total_voters_count)
    @total_dials_made_leads = total_dials(leads_grouped_by_status_filtered)
  end
  
  def total_dials_made_leads
    @total_dials_made_leads
  end
  
  def per_attempt_dials
    @total_attempts_count = @campaign.call_attempts.between(@from_date, @to_date).count
    @per_attempt_dials = @campaign.call_attempts.between(@from_date, @to_date).group("status").count
    @total_attempt_dials = ((@total_attempts_count == 0) ? 1 : @total_attempts_count)
    @ready_to_dial_attempts = params[:from_date] ? 0 : sanitize_dials(@per_attempt_dials[CallAttempt::Status::READY])
    @total_dials_made_attempts = total_dials(@per_attempt_dials)
  end
  
  def sanitize_dials(dial_count)
    dial_count.nil? ? 0 : dial_count
  end
  
  def total_dials(dials_made)
    return 1 if dials_made.empty?
    sanitize_dials(dials_made[CallAttempt::Status::SUCCESS]).to_i + sanitize_dials(dials_made['retry']).to_i + 
    sanitize_dials(dials_made[CallAttempt::Status::NOANSWER]).to_i + sanitize_dials(dials_made[CallAttempt::Status::BUSY]).to_i + 
    sanitize_dials(dials_made[CallAttempt::Status::HANGUP]).to_i + sanitize_dials(dials_made[CallAttempt::Status::VOICEMAIL]).to_i + 
    sanitize_dials(dials_made[CallAttempt::Status::SCHEDULED]).to_i + sanitize_dials(dials_made[CallAttempt::Status::ABANDONED]).to_i
  end
  
  
  
   
end
