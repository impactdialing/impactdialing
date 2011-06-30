module Client
  class ReportsController < ClientController

    def usage
      user_attempts = CallAttempt.for_campaign(Campaign.find(params[:id]))
      @call_minutes = user_attempts.for_status("Call completed with success.").inject(0){|sum, x| sum + x.duration} / 60
      @voicemail_minutes = user_attempts.for_status("Message delivered").inject(0){|sum, x| sum + x.duration} / 60
    end
  end
end
