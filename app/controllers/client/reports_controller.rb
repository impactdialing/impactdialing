module Client
  class ReportsController < ClientController
    def usage
      @campaign = @user.all_campaigns.find(params[:id])

      set_report_date_range

      all_call_attempts = @campaign.call_attempts.between(@from_date, @to_date + 1.day)

      @utilised_call_attempts_seconds = all_call_attempts.sum(:tDuration)
      @utilised_call_attempts_minutes = all_call_attempts.sum('ceil(tDuration/60)').to_i

      @caller_sessions_seconds = @campaign.caller_sessions.between(@from_date, @to_date).sum(:tDuration)
      @caller_sessions_minutes = @campaign.caller_sessions.between(@from_date, @to_date).sum('ceil(tDuration/60)').to_i

      @billable_call_attempts_seconds = all_call_attempts.without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum(:tDuration)
      @billable_call_attempts_minutes = all_call_attempts.without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i

      @billable_voicemail_seconds = all_call_attempts.with_status([CallAttempt::Status::VOICEMAIL]).sum(:tDuration)
      @billable_voicemail_minutes = all_call_attempts.with_status([CallAttempt::Status::VOICEMAIL]).sum('ceil(tDuration/60)').to_i

      @billable_abandoned_seconds = all_call_attempts.with_status([CallAttempt::Status::ABANDONED]).sum(:tDuration)
      @billable_abandoned_minutes = all_call_attempts.with_status([CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i
    end
  end
end
