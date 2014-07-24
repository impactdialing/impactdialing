require Rails.root.join("jobs/report_download_job")
module Client
  class ReportsController < ClientController
    include ApplicationHelper::TimeUtils
    include TimeZoneHelper
    before_filter :load_campaign, :except => [:index, :usage, :account_campaigns_usage, :account_callers_usage, :performance]
    before_filter :campaigns_and_callers_exist?

    around_filter :select_shard
    respond_to :html, :json

  private
    def report_response_strategy
      unless session[:internal_admin]
        return params[:strategy]
      else
        'web-internal-admin'
      end
    end

    def campaigns_and_callers_exist?
      campaign_flag = account.campaigns.empty?
      caller_flag   = account.callers.empty?
      if campaign_flag or caller_flag
        notice = ['Please create at least one campaign and one caller to load reports.']
        notice << 'Missing:'
        missing = []
        missing << 'campaign' if campaign_flag
        missing << 'caller' if caller_flag
        notice << missing.join(', ')
        redirect_to client_root_path, notice: notice.join(' ')
      end
    end

  public

    def index
      @campaigns = params[:id].blank? ? account.campaigns : Campaign.find(params[:id])
      @download_report_count = DownloadedReport.accounts_active_report_count(@campaigns.collect{|c| c.id}, session[:internal_admin])
      @callers = account.callers.active
    end

    def performance
      authorize! :view_reports, @account

      from_date_pool = []
      to_date_pool   = []

      from_date_pool << params[:from_date]
      to_date_pool   << params[:to_date]

      if params[:campaign_id].present?
        mode = :campaign
        load_campaign
        @record = @campaign
        from_date_pool << @campaign.created_at
        time_zone = @record.time_zone
      else
        mode = :caller
        load_caller
        @record = @caller
        from_date_pool << @record.caller_sessions.first.try(:created_at)
        from_date_pool << @record.created_at
        time_zone = @record.campaign.time_zone
      end

      @date_range = Report::SelectiveDateRange.new(from_date_pool, to_date_pool, time_zone)

      @velocity = Report::Performance::VelocityController.render(:html, {
        record: @record,
        from_date: @date_range.from,
        to_date: @date_range.to,
        mode: mode,
        description: 'Here are some statistical averages to help you gain a general understanding of how a campaign is performing over time.'
      })
    end

    def dials
      authorize! :view_reports, @account
      load_campaign
      set_dates

      if params[:from_date].blank? || params[:to_date].blank?
        @overview = Report::Dials::SummaryController.render(:html, {
          campaign: @campaign,
          heading: 'Overview',
          description: 'The data in the overview table gives the current state of the campaign.'
        })
      else
        @overview = ''
      end
      @by_contact = Report::Dials::ByStatusController.render(:html, {
        campaign: @campaign,
        scoped_to: :all_voters,
        from_date: @from_date,
        to_date: @to_date,
        heading: "Per lead",
        description: "The data in the per lead table includes only the most recent status for each lead."
      })
      @by_attempt = Report::Dials::ByStatusController.render(:html, {
        campaign: @campaign,
        scoped_to: :call_attempts,
        from_date: @from_date,
        to_date: @to_date,
        heading: "Per dial",
        description: "The data in the per dial table includes every status for each lead."
      })
    end

    def answer
      authorize! :view_reports, @account
      load_campaign
      set_dates
      @results = @campaign.answers_result(@from_date, @to_date)
      @transfers = @campaign.transfers(@from_date, @to_date)
    end

    def usage
      authorize! :view_reports, @account
      load_campaign
      set_dates
      @campaign_usage = CampaignUsage.new(@campaign, @from_date, @to_date)
    end

    def download_report
      authorize! :view_reports, @account
      load_campaign
      set_dates
      @voter_fields = VoterList::VOTER_DATA_COLUMNS
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}
    end

    def download
      authorize! :view_reports, @account
      load_campaign
      set_dates
      Resque.enqueue(ReportDownloadJob, @campaign.id, @user.id,
        params[:voter_fields],
        params[:custom_voter_fields],
        params[:download_all_voters],
        params[:lead_dial],
        @from_date, @to_date, params[:callback_url], report_response_strategy
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
      authorize! :view_reports, @account
      load_campaign
      @downloaded_reports = DownloadedReport.active_reports(@campaign.id, session[:internal_admin])
    end

    private

    def load_campaign
      Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)) do
        @campaign = Account.find(account).campaigns.find(params[:campaign_id])
      end
      @datepicker_target = performance_client_campaign_reports_path({campaign_id: @campaign.id})
      @campaign
    end

    def load_caller
      Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)) do
        @caller = Account.find(account).callers.find(params[:caller_id])
      end
      @datepicker_target = performance_client_caller_reports_path({caller_id: @caller.id})
      @caller
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
