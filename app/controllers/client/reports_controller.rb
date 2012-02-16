module Client
  class ReportsController < ClientController
    before_filter :load_campaign, :except => [:index, :usage]
    before_filter :set_report_date_range, :only => [:usage]

    def load_campaign
      @campaign = Campaign.find(params[:campaign_id])
    end

    def index
      @campaigns = params[:id].blank? ? account.campaigns.manual : Campaign.find(params[:id])
    end
    
    def dials
      set_date_range

      dialed_voters = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date)
      @total_voters_count = @campaign.all_voters.count
      dialed_voters_ids = dialed_voters.collect{|x| x.id} 
      if dialed_voters
        @answered = @campaign.answered_count(dialed_voters_ids)
        @no_answer = dialed_voters.by_status(CallAttempt::Status::NOANSWER).count
        @busy_signal = dialed_voters.by_status(CallAttempt::Status::BUSY).count
        @answering_machine = dialed_voters.by_status(CallAttempt::Status::HANGUP).count
        @voicemail = dialed_voters.by_status(CallAttempt::Status::VOICEMAIL).count
        @ringing = dialed_voters.by_status(CallAttempt::Status::RINGING).count
        @abandoned = dialed_voters.by_status(CallAttempt::Status::ABANDONED).count
        @failed = dialed_voters.by_status(CallAttempt::Status::FAILED).count
        @scheduled = dialed_voters.by_status(CallAttempt::Status::SCHEDULED).count
      end
      @total = ((@total_voters_count == 0) ? 1 : @total_voters_count)
      @ready_to_dial = params[:from_date] ? 0 : @campaign.all_voters.by_status(CallAttempt::Status::READY).count
      @not_dialed = not_dilaed_voters(params[:from_date])
      @total_dials = @answered.to_i + @no_answer.to_i + @busy_signal.to_i + @ringing.to_i + @abandoned.to_i + @failed.to_i + @voicemail.to_i + @scheduled.to_i + @answering_machine.to_i
    end

    def usage
      @campaign = current_user.campaigns.find(params[:id])
    end
    
    def download_report
      set_date_range
      @voter_fields = VoterList::VOTER_DATA_COLUMNS
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}      
    end

    def download
      set_date_range
      Delayed::Job.enqueue ReportJob.new(@campaign, @user, params[:voter_fields], params[:custom_voter_fields], params[:download_all_voters], @from_date, @to_date)
      flash_message(:notice, I18n.t(:client_report_processing))
      redirect_to client_reports_url
    end

    def answer
      set_date_range
      @results = @campaign.answers_result(@from_date, @to_date)
      @transfers = @campaign.transfers(@from_date, @to_date)
    end

    private
    
    def set_date_range
      time_zone = ActiveSupport::TimeZone.new(@campaign.time_zone || "UTC")
      from_date = Time.strptime("#{params[:from_date]} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if params[:from_date]
      to_date = Time.strptime("#{params[:to_date]} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if params[:to_date]
      @from_date = (from_date || @campaign.call_attempts.first.try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day
      @to_date = (to_date || @campaign.call_attempts.last.try(:created_at) || Time.now).in_time_zone(time_zone).end_of_day
    end
    
    def not_dilaed_voters(range_parameters)
      if range_parameters
        @total_voters_count - (@answered.to_i + @no_answer.to_i + @busy_signal.to_i + @ringing.to_i + @abandoned.to_i + @failed.to_i + @voicemail.to_i + @scheduled.to_i + @answering_machine.to_i)
      else
        @campaign.all_voters.by_status(Voter::Status::NOTCALLED).count
      end
    end
  end
end
