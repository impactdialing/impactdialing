require Rails.root.join("lib/twilio_lib")

class AdminController < ApplicationController
  USER_NAME, PASSWORD = "impact", ENV['ADMIN_PASSWORD'] || rand
  before_filter :authenticate

  rescue_from 'Enterprise::UpgradeError' do |exception|
    flash[:error] = [exception.message]
    redirect_to :back
  end

  rescue_from Report::SelectiveDateRange::InvalidDateFormat, with: :rescue_invalid_date

  if instrument_actions?
    instrument_action :state, :twilio_limit, :caller_sessions, :users, :campaign_stats, :report
  end

private
  def rescue_invalid_date(exception)
    flash[:error] = [exception.message]
    redirect_to :back
  end

  def build_date_pool(param_name, record_pool=[])
    date_pool = []
    date_pool << params[param_name]
    record_pool.each do |record|
      next if record.nil?
      date_pool << record
    end
    date_pool
  end

public
  def state
    @logged_in_campaigns = Campaign.where("id in (select distinct campaign_id from caller_sessions where on_call = 1 )")
    @logged_in_campaigns = @logged_in_campaigns.where(type: 'predictive') if params[:type] == 'predictive'
    @logged_in_callers_count = CallerSession.on_call.count
    @errors=""
  end

  def fix_counts
    Campaign.find(params[:id]).inflight_stats.incby(params[:metric], params[:amount])
    redirect_to :back
  end

  def twilio_limit
    TwilioLimit.set(params["twilio_limit"])
    redirect_to :back
  end

  def caller_sessions
    campaign = Campaign.find(params[:id])
    render json: {
        html: render_to_string(
            partial: "caller_sessions",
            locals: {
                caller_sessions: campaign.caller_sessions.on_call.includes(:caller),
                campaign: campaign
            }
        )
    }
  end


  def campaign_stats
    Octopus.using(OctopusConnection.dynamic_shard(:read_slave1, :read_slave2)) do
      campaign = Campaign.find(params[:id])
      @time_span = params[:time_span] || 5
      @number_of_callers = campaign.caller_sessions.on_call.size
      simulated_values = SimulatedValues.find_by_campaign_id(campaign.id)
      @last_siumlated_time = simulated_values.try(:updated_at) || Time.at(0)
      @best_dials = simulated_values.try(:best_dials)
      @num_dials = campaign.call_attempts.between(@time_span.to_i.minutes.ago, Time.now).size
      @num_answered_dials = campaign.call_attempts.between(@time_span.to_i.minutes.ago, Time.now).with_status(CallAttempt::Status::SUCCESS).size
      @number_of_callers_on_hold = campaign.caller_sessions.available.where("updated_at < ?", 2.minutes.ago).size
    end
  end

  def abandonment
    account = Account.find(params[:id])
    if account.variable_abandonment?
      account.update_attributes(abandonment: "fixed")
    else
      account.update_attributes(abandonment: "variable")
    end
    redirect_to :back
  end

  def index

  end

  def report
    from_date_pool = build_date_pool(:from_date, [Time.now.in_time_zone('Pacific Time (US & Canada)').beginning_of_month])
    to_date_pool   = build_date_pool(:to_date)

    @date_range = Report::SelectiveDateRange.new(from_date_pool, to_date_pool)

    if request.post?
      flash.now[:notice] = ["Your #{report_type} report (#{params[:from_date]} - #{params[:to_date]}) has been added to the queue. You should receive it via email when complete."]
      Resque.enqueue(AdminReportJob, params[:from_date], params[:to_date], report_type, reports_include_undebited)
    end
  end

  def users
    @accounts = Account.includes(:billing_subscription)
    if params[:query].present?
      @accounts = @accounts.search(params[:query])
    else
      @accounts = @accounts.includes(:users)
    end
    @accounts = @accounts.paginate :page => params[:page]
  end

  def toggle_calling
    account = Account.find(params[:id])
    quota   = account.quota
    quota.toggle_calling!
    word = quota.disable_calling? ? 'denied' : 'allowed'
    redirect_to :back, notice: ["Dialer access #{word} for Account##{account.id}."]
  end

  def toggle_access
    account = Account.find(params[:id])
    quota   = account.quota
    quota.toggle_access!
    word = quota.disable_access? ? 'denied' : 'allowed'
    redirect_to :back, notice: ["Admin & dialer access #{word} for Account##{account.id}."]
  end

  def login
    session[:internal_admin] = true
    session[:user]           = params[:id]

    redirect_to :controller => "client", :action => "index"
  end

  def destroy_user
    @user = User.find(params[:id])
    @user.destroy
    redirect_to :back
  end

  private
    def authenticate
      authenticate_or_request_with_http_basic(self.class.controller_path) do |user_name, password|
        user_name == USER_NAME && password == PASSWORD
      end
    end

    def report_type
      params[:report_type] == 'all' ? 'All' : 'Enterprise'
    end

    def reports_include_undebited
      !!params[:include_undebited]
    end
end
