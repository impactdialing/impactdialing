module Client
  class ReportsController < ClientController
    include ApplicationHelper::TimeUtils
    before_filter :load_campaign, :except => [:index, :usage]


    def load_campaign
      @campaign = Campaign.find(params[:campaign_id])
    end

    def index
      @campaigns = params[:id].blank? ? account.campaigns.manual : Campaign.find(params[:id])
      @download_report_count = DownloadedReport.accounts_active_report_count(@campaigns.collect{|c| c.id})
      @callers = account.callers.active
    end

    
    def dials
      set_date_range
      @total_voters_count = @campaign.all_voters.count
      @answered = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::SUCCESS).count + @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status('retry').count
      @no_answer = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::NOANSWER).count
      @busy_signal = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::BUSY).count
      @answering_machine = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::HANGUP).count
      @voicemail = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::VOICEMAIL).count
      @ringing = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::RINGING).count
      @abandoned = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::ABANDONED).count
      @failed = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::FAILED).count
      @scheduled = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::SCHEDULED).count
      @total = ((@total_voters_count == 0) ? 1 : @total_voters_count)
      @ready_to_dial = params[:from_date] ? 0 : @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::READY).count
      @not_dialed = not_dilaed_voters(@from_date)
      @total_dials = @answered.to_i + @no_answer.to_i + @busy_signal.to_i + @ringing.to_i + @abandoned.to_i + @failed.to_i + @voicemail.to_i + @scheduled.to_i + @answering_machine.to_i
    end

    def usage
      @campaign = current_user.campaigns.find(params[:id])
      set_date_range
      @time_logged_in = round_for_utilization(CallerSession.time_logged_in(nil, @campaign, @from_date, @to_date))
      @time_on_call = round_for_utilization(CallAttempt.time_on_call(nil, @campaign, @from_date, @to_date))
      @time_in_wrapup = round_for_utilization(CallAttempt.time_in_wrapup(nil, @campaign, @from_date, @to_date))
      @time_onhold = round_for_utilization(CallerSession.time_logged_in(nil, @campaign, @from_date, @to_date).to_f - CallAttempt.time_on_call(nil, @campaign, @from_date, @to_date).to_f - CallAttempt.time_in_wrapup(nil, @campaign, @from_date, @to_date).to_f)
      @caller_time = CallerSession.caller_time(nil, @campaign, @from_date, @to_date)
      @lead_time = CallAttempt.lead_time(nil, @campaign, @from_date, @to_date)
      @transfer_time = @campaign.transfer_time(@from_date, @to_date)
      @voice_mail_time = @campaign.voicemail_time(@from_date, @to_date)
      @abandoned_time = @campaign.abandoned_calls_time(@from_date, @to_date)
      @total_time = @caller_time + @lead_time + @transfer_time + @voicemail_time + @abandoned_calls_time
    end
    
    def downloaded_reports
      @downloaded_reports = DownloadedReport.active_reports(@campaign.id)
    end
    
    def download_report
      set_date_range
      @voter_fields = VoterList::VOTER_DATA_COLUMNS
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}      
    end

    def download
      set_date_range
      Delayed::Job.enqueue ReportJob.new(@campaign, @user, params[:voter_fields], params[:custom_voter_fields], params[:download_all_voters],params[:lead_dial], @from_date, @to_date, "", "webui")
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
      begin
        from_date = Time.strptime("#{params[:from_date]} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if params[:from_date]
        to_date = Time.strptime("#{params[:to_date]} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if params[:to_date]
      rescue Exception => e
        flash_message(:error, I18n.t(:invalid_date_format))
        redirect_to :back
        return
      end      
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
