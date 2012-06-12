require Rails.root.join("jobs/report_download_job")
class ReportsController < ClientController
  layout 'v2'
  before_filter :load_campaign, :only => [:usage, :dials, :answers]

  def load_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end
  
  def index
    @campaigns = account.campaigns.robo.active
  end

  def usage
    @minutes = @campaign.call_attempts.with_status([CallAttempt::Status::SUCCESS,CallAttempt::Status::VOICEMAIL,CallAttempt::Status::HANGUP,CallAttempt::Status::ABANDONED]).sum('ceil(TIMESTAMPDIFF(SECOND ,connecttime,call_end)/60)').to_i
  end
  
  def answers
    set_report_period
    @results = @campaign.answer_results(@from_date, @to_date)
    render :template => 'client/reports/answer'
  end
  
  
  def dials
    set_report_period
    @total_voters_count = @campaign.all_voters.count    
    dialed_voters_ids = Voter.find(:all, :select => 'id' ,:conditions => [ "(voters.campaign_id = ?) AND (last_call_attempt_time BETWEEN  ? AND ?) ", @campaign.id, @from_date, @to_date])

    unless dialed_voters_ids.empty?
      @answered = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::ANSWERED).count
      @no_answer = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::NOANSWER).count
      @busy_signal = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::BUSY).count
      @answering_machine = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::HANGUP).count
      @voicemail = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::VOICEMAIL).count
      @ringing = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::RINGING).count
      @failed = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date).by_status(CallAttempt::Status::FAILED).count
    end
    @total = ((@total_voters_count == 0) ? 1 : @total_voters_count)
    @not_dialed = not_dilaed_voters(params[:from_date])
    @total_dials = @answered.to_i + @no_answer.to_i + @busy_signal.to_i + @answering_machine.to_i + @voicemail.to_i + @ringing.to_i + @failed.to_i
  end
  
  def dial_details
    @campaign = account.campaigns.find(params[:id])
    set_report_period
    @voter_fields = VoterList::VOTER_DATA_COLUMNS
    @custom_voter_fields = @user.account.custom_fields.collect{ |field| field.name}    
  end
  
  def downloaded_reports
  end
  
  def download
    @campaign = account.campaigns.find(params[:id])
    set_report_period
    # Delayed::Job.enqueue ReportJob.new(@campaign, @user, params[:voter_fields], params[:custom_voter_fields], params[:download_all_voters], params[:lead_dial], @from_date, @to_date, "", "webui")
    Resque.enqueue(ReportDownloadJob, @campaign.id, @user.id, params[:voter_fields], params[:custom_voter_fields], params[:download_all_voters], params[:lead_dial], @from_date, @to_date, "", "webui")
    flash_message(:notice, I18n.t(:client_report_processing))
    redirect_to reports_url
  end
  
  private
  
  def set_report_period
    from_date = Date.strptime(params[:from_date], "%m/%d/%Y") if params[:from_date]
    to_date = Date.strptime(params[:to_date], "%m/%d/%Y") if params[:to_date]
    @from_date = from_date || (@campaign.call_attempts.first.try(:created_at) || Time.now)
    @to_date = to_date || Time.now
  end
  
  def not_dilaed_voters(range_parameters)
    if range_parameters
      @total_voters_count - (@answered.to_i + @no_answer.to_i + @busy_signal.to_i + @ringing.to_i + @failed.to_i + @answering_machine.to_i + @voicemail.to_i)
    else
      @campaign.all_voters.by_status(Voter::Status::NOTCALLED).count
    end
  end
end
