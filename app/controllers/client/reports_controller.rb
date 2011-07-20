module Client
  class ReportsController < ClientController

    def usage
      user_attempts = CallAttempt.for_campaign(Campaign.find(params[:id]))
      @call_minutes = user_attempts.for_status(CallAttempt::Status::SUCCESS).inject(0){|sum, x| sum + x.duration_rounded_up}
      @voicemail_minutes = user_attempts.for_status(CallAttempt::Status::VOICEMAIL).inject(0){|sum, x| sum + x.duration_rounded_up}
    end
  end
end
