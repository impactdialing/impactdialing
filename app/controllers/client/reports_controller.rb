require Rails.root.join("jobs/report_download_job")
module Client
  class ReportsController < ClientController
    include ApplicationHelper::TimeUtils
    include TimeZoneHelper
    before_filter :load_campaign, :except => [:index, :usage, :account_campaigns_usage, :account_callers_usage]
    around_filter :select_shard
    respond_to :html, :json

    def index
      @campaigns = params[:id].blank? ? account.campaigns : Campaign.find(params[:id])
      @download_report_count = DownloadedReport.accounts_active_report_count(@campaigns.collect{|c| c.id})
      @callers = account.callers.active
    end

    def dials
      load_campaign
      set_dates
      @show_summary = true if params[:from_date].blank? || params[:to_date].blank?
      @dials_report = DialReport.new
      @dials_report.compute_campaign_report(@campaign, @from_date, @to_date)
    end

    def answer
      load_campaign
      set_dates
      @results = @campaign.answers_result(@from_date, @to_date)
      @transfers = @campaign.transfers(@from_date, @to_date)
    end

    def usage
      load_campaign
      set_dates
      @campaign_usage = CampaignUsage.new(@campaign, @from_date, @to_date)
    end

    def download_report
      load_campaign
      set_dates
      @voter_fields = VoterList::VOTER_DATA_COLUMNS
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}
    end

    def download
      load_campaign
      set_dates
      Resque.enqueue(ReportDownloadJob, @campaign.id, @user.id,
        params[:voter_fields],
        params[:custom_voter_fields],
        params[:download_all_voters],
        params[:lead_dial],
        @from_date, @to_date, params[:callback_url], params[:strategy]
      )
      respond_with(@campaign, location:  client_reports_url) do |format|
        format.html {
            flash_message(:notice, I18n.t(:client_report_processing))
            redirect_to client_reports_url
          }
        format.json {
          render :json => {message: "Response will be sent to the callback url once the report is ready for download." }}
      end
    end

    def downloaded_reports
      load_campaign
      @downloaded_reports = DownloadedReport.active_reports(@campaign.id)
    end


    def account_campaigns_usage
      @account = Account.find(params[:id])
      @campaigns = @account.all_campaigns
      @from_date, @to_date = set_date_range_account(@account, params[:from_date], params[:to_date])
      account_usage = AccountUsage.new(@account, @from_date, @to_date)
      @billiable_total = account_usage.billable_usage
    end

    def account_callers_usage
      @account = Account.find(params[:id])
      @callers = @account.callers
      @from_date, @to_date = set_date_range_account(@account, params[:from_date], params[:to_date])
      account_usage = AccountUsage.new(@account, @from_date, @to_date)
      @billiable_total = account_usage.callers_billable_usage
      @status_usage = account_usage.callers_status_times
      @final_total = @billiable_total.values.inject(0){|sum,x| sum+x} + sanitize_dials(@status_usage[CallAttempt::Status::ABANDONED]).to_i +
      sanitize_dials(@status_usage[CallAttempt::Status::VOICEMAIL]).to_i + sanitize_dials(@status_usage[CallAttempt::Status::HANGUP]).to_i
    end

    private

    def load_campaign
      Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)) do
        @campaign = Account.find(account).campaigns.find(params[:campaign_id])
      end
    end

    def set_dates
      @from_date, @to_date = set_date_range(@campaign, params[:from_date], params[:to_date])
    end

    def sanitize(count)
      count.nil? ? 0 : count
    end

    def not_dialed_voters(range_parameters, total_dials)
      if range_parameters
        @total_voters_count - total_dials
      else
        @campaign.all_voters.enabled.by_status(Voter::Status::NOTCALLED).count
      end
    end
  end
end
