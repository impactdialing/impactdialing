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
    @minutes = @campaign.call_attempts.for_status(CallAttempt::Status::SUCCESS).inject(0) { |sum, ca| sum + ca.minutes_used }
  end
  
  def answers
    set_report_period
    @results = @campaign.robo_answer_results(@from_date, @to_date)
    render :template => 'client/reports/answer'
  end
  
  def dials
    set_report_period
    
    dialed_voters = @campaign.all_voters.last_call_attempt_within(@from_date, @to_date)
    @total_voters = @campaign.all_voters
    if dialed_voters
      @answered = dialed_voters.by_status(CallAttempt::Status::ANSWERED).count
      @no_answer = dialed_voters.by_status(CallAttempt::Status::NOANSWER).count
      @busy_signal = dialed_voters.by_status(CallAttempt::Status::BUSY).count
      @answering_machine = dialed_voters.by_status(CallAttempt::Status::HANGUP).count
      @voicemail = dialed_voters.by_status(CallAttempt::Status::VOICEMAIL).count
      @ringing = dialed_voters.by_status(CallAttempt::Status::RINGING).count
      @failed = dialed_voters.by_status(CallAttempt::Status::FAILED).count
    end
    @total = ((@total_voters.count == 0) ? 1 : @total_voters.count)
    @not_dialed = not_dilaed_voters(params[:from_date])
    @total_dials = @answered.to_i + @no_answer.to_i + @busy_signal.to_i + @answering_machine.to_i + @voicemail.to_i + @ringing.to_i + @failed.to_i
  end
  
  def dial_details
    @campaign = account.campaigns.find(params[:id])
    set_report_period
    @voter_fields = VoterList::VOTER_DATA_COLUMNS
    @custom_voter_fields = @user.account.custom_fields.collect{ |field| field.name}
    respond_to do |format|
      format.html
      format.csv do
        Delayed::Job.enqueue ReportJob.new(@campaign, @user, params[:voter_fields], params[:custom_voter_fields], params[:download_all_voters], @from_date, @to_date)
        redirect_to reports_url, :flash => {:notice => I18n.t(:client_report_processing)}
      end
    end
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
      @total_voters.count - (@answered.to_i + @no_answer.to_i + @busy_signal.to_i + @ringing.to_i + @failed.to_i)
    else
      @total_voters.by_status(Voter::Status::NOTCALLED).count
    end
  end
end
