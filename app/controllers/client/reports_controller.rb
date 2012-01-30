module Client
  class ReportsController < ClientController
    before_filter :load_campaign, :except => [:index, :usage]

    def load_campaign
      @campaign = Campaign.find(params[:campaign_id])
    end

    def index
      @campaigns = params[:id].blank? ? account.campaigns.manual : Campaign.find(params[:id])
    end
    
    def dials
      from_date = Date.strptime(params[:from_date], "%m/%d/%Y") if params[:from_date]
      to_date = Date.strptime(params[:to_date], "%m/%d/%Y") if params[:to_date]
      @from_date = from_date || (@campaign.call_attempts.first.try(:created_at) || Time.now)
      @to_date = to_date || Time.now

      dialed_voters = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date)
      @total_voters_count = @campaign.all_voters.count
      dialed_voters_ids = dialed_voters.collect{|x| x.id} 
      if dialed_voters
        @answered = @campaign.answered_count(dialed_voters_ids)
        @no_answer = dialed_voters.by_status(CallAttempt::Status::NOANSWER).count
        @busy_signal = dialed_voters.by_status(CallAttempt::Status::BUSY).count
        @ringing = dialed_voters.by_status(CallAttempt::Status::RINGING).count
        @abandoned = dialed_voters.by_status(CallAttempt::Status::ABANDONED).count
        @failed = dialed_voters.by_status(CallAttempt::Status::FAILED).count
        @voicemail = dialed_voters.by_status(CallAttempt::Status::VOICEMAIL).count
        @scheduled = dialed_voters.by_status(CallAttempt::Status::SCHEDULED).count
      end
      @total = ((@total_voters_count == 0) ? 1 : @total_voters_count)
      @ready_to_dial = params[:from_date] ? 0 : @campaign.all_voters.by_status(CallAttempt::Status::READY).count
      @not_dialed = not_dilaed_voters(params[:from_date])
    end

    def usage
      @campaign = @user.all_campaigns.find(params[:id])
      set_report_date_range

      all_call_attempts = @campaign.call_attempts.between(@from_date, @to_date + 1.day)
      @utilised_call_attempts_seconds = round_for_utilization(all_call_attempts.sum(:tDuration))
      @utilised_call_attempts_minutes = all_call_attempts.sum('ceil(tDuration/60)').to_i
      

      @caller_sessions_seconds = round_for_utilization(@campaign.caller_sessions.between(@from_date, @to_date + 1.day).sum(:tDuration))
      @caller_sessions_minutes = @campaign.caller_sessions.between(@from_date, @to_date + 1.day).sum('ceil(tDuration/60)').to_i


      @billable_call_attempts_seconds = round_for_utilization(all_call_attempts.without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum(:tDuration))
      @billable_call_attempts_minutes = all_call_attempts.without_status([CallAttempt::Status::VOICEMAIL, CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i


      @billable_voicemail_seconds = round_for_utilization(all_call_attempts.with_status([CallAttempt::Status::VOICEMAIL]).sum(:tDuration))
      @billable_voicemail_minutes = all_call_attempts.with_status([CallAttempt::Status::VOICEMAIL]).sum('ceil(tDuration/60)').to_i
      

      @billable_abandoned_seconds = round_for_utilization(all_call_attempts.with_status([CallAttempt::Status::ABANDONED]).sum(:tDuration))
      @billable_abandoned_minutes = all_call_attempts.with_status([CallAttempt::Status::ABANDONED]).sum('ceil(tDuration/60)').to_i
    end
    
    def round_for_utilization(seconds)
      if seconds == 0
        0
      else
        (seconds/60).to_s + "." + (seconds % 60).to_s
      end
    end

    def download
      from_date = Date.strptime(params[:from_date], "%m/%d/%Y") if params[:from_date]
      to_date = Date.strptime(params[:to_date], "%m/%d/%Y") if params[:to_date]
      @from_date = from_date || (@campaign.call_attempts.first.try(:created_at) || Date.today)
      @to_date = to_date || (@campaign.call_attempts.last.try(:created_at) || Date.today)

      @voter_fields = VoterList::VOTER_DATA_COLUMNS
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}
      respond_to do |format|
        format.html
        format.csv do
          Delayed::Job.enqueue ReportJob.new(@campaign, @user, params[:voter_fields], params[:custom_voter_fields], params[:download_all_voters], @from_date, @to_date)
          flash_message(:notice, I18n.t(:client_report_processing))
          redirect_to client_reports_url
        end
      end
    end

    def answer
      set_report_date_range
      @results = @campaign.answers_result(@from_date, @to_date)
    end

    private
    
    def not_dilaed_voters(range_parameters)
      if range_parameters
        @total_voters_count - (@answered.to_i + @no_answer.to_i + @busy_signal.to_i + @ringing.to_i + @abandoned.to_i + @failed.to_i + @voicemail.to_i + @scheduled.to_i)
      else
        @campaign.all_voters.by_status(Voter::Status::NOTCALLED).count
      end
    end
  end
end
