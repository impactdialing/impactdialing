require Rails.root.join("jobs/report_download_job")
module Client
  class ReportsController < ClientController
    include ApplicationHelper::TimeUtils
    include TimeZoneHelper
    before_filter :load_campaign, :except => [:index, :usage, :account_campaigns_usage, :account_callers_usage, :performance]
    before_filter :campaigns_and_callers_exist?

    around_filter :select_shard
    respond_to :html, :json

    rescue_from Report::SelectiveDateRange::InvalidDateFormat, with: :rescue_invalid_date

  private
    def rescue_invalid_date(exception)
      flash[:error] = [exception.message]
      redirect_to :back
    end

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
        notice = 'Please create at least one campaign and one caller before loading reports. '
        notice << 'Missing: '
        missing = []
        missing << 'campaigns' if campaign_flag
        missing << 'callers' if caller_flag
        notice << missing.to_sentence
        redirect_to client_root_path, notice: [notice]
      end
    end

    def build_date_pool(param_name, record_pool=[])
      date_pool = []
      date_pool << params[param_name]
      record_pool.each do |record|
        next if record.nil?
        date_pool << record.created_at
      end
      date_pool
    end

  public

    def index
      @campaigns = params[:id].blank? ? account.campaigns : Campaign.find(params[:id])
      @download_report_count = DownloadedReport.accounts_active_report_count(@campaigns.collect{|c| c.id}, session[:internal_admin])
      @callers = account.callers.active
    end

    def performance
      authorize! :view_reports, @account

      if params[:campaign_id].present?
        mode = :campaign
        load_campaign
        @record = @campaign
        from_date_pool = build_date_pool(:from_date, [@campaign])
        time_zone = @record.time_zone
      else
        mode = :caller
        load_caller
        @record = @caller
        from_date_pool = build_date_pool(:from_date, [@record.caller_sessions.first, @record])
        time_zone = @record.campaign.time_zone
      end

      to_date_pool = build_date_pool(:to_date)

      @date_range = Report::SelectiveDateRange.new(from_date_pool, to_date_pool, time_zone)

      @velocity = Report::Performance::VelocityController.render(:html, {
        record: @record,
        from_date: @date_range.from,
        to_date: @date_range.to,
        mode: mode,
        description: 'Here are some statistical averages to help you gain a general understanding of how a campaign is performing over time.'
      })
    end

    def dials_summary
      authorize! :view_reports, @account
      load_campaign
      @overview = Report::Dials::SummaryController.render(:html, {
        campaign: @campaign,
        heading: 'Overview',
        description: 'The data in the overview table gives the current state of the campaign.'
      })
    end

    def dials
      authorize! :view_reports, @account
      load_campaign

      params[:dials_view] ||= 'by_lead'

      from_date_pool = build_date_pool(:from_date, [@campaign])
      to_date_pool   = build_date_pool(:to_date)

      @date_range = Report::SelectiveDateRange.new(from_date_pool, to_date_pool, @campaign.time_zone)

      if params[:dials_view] == 'by_lead'
        @report = Report::Dials::ByStatusController.render(:html, {
          campaign: @campaign,
          scoped_to: :all_voters,
          from_date: @date_range.from,
          to_date: @date_range.to,
          heading: "Per lead",
          description: "The data in the per lead table includes only the most recent status for each lead."
        })
        @report_link_text = 'Per dial'
        @report_link_view = 'by_dial'
      else
        @report = Report::Dials::ByStatusController.render(:html, {
          campaign: @campaign,
          scoped_to: :call_attempts,
          from_date: @date_range.from,
          to_date: @date_range.to,
          heading: "Per dial",
          description: "The data in the per dial table includes every status for each lead."
        })
        @report_link_text = 'Per lead'
        @report_link_view = 'by_lead'
      end
    end

    def answer
      authorize! :view_reports, @account
      load_campaign
      
      from_date_pool = build_date_pool(:from_date, [@campaign])
      to_date_pool   = build_date_pool(:to_date)
      @date_range    = Report::SelectiveDateRange.new(from_date_pool, to_date_pool, @campaign.time_zone)

      @results   = @campaign.answers_result(@date_range.from, @date_range.to)
      @transfers = @campaign.transfers(@date_range.from, @date_range.to)
    end

    def usage
      authorize! :view_reports, @account
      load_campaign

      from_date_pool = build_date_pool(:from_date, [@campaign])
      to_date_pool = build_date_pool(:to_date)

      @date_range     = Report::SelectiveDateRange.new(from_date_pool, to_date_pool, @campaign.time_zone)
      @campaign_usage = CampaignUsage.new(@campaign, @date_range.from, @date_range.to)
    end

    def download_report
      authorize! :view_reports, @account
      load_campaign
      from_date_pool       = build_date_pool(:from_date, [@campaign])
      to_date_pool         = build_date_pool(:to_date)
      @date_range          = Report::SelectiveDateRange.new(from_date_pool, to_date_pool, @campaign.time_zone)
      @voter_fields        = VoterList::VOTER_DATA_COLUMNS
      @custom_voter_fields = @user.account.custom_voter_fields.collect{ |field| field.name}
    end

    def download
      authorize! :view_reports, @account
      load_campaign
      from_date_pool = build_date_pool(:from_date, [@campaign])
      to_date_pool   = build_date_pool(:to_date)
      @date_range    = Report::SelectiveDateRange.new(from_date_pool, to_date_pool, @campaign.time_zone)
      Resque.enqueue(ReportDownloadJob, @campaign.id, @user.id,
        params[:voter_fields],
        params[:custom_voter_fields],
        params[:download_all_voters],
        params[:lead_dial],
        @date_range.from, @date_range.to, params[:callback_url], report_response_strategy
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
