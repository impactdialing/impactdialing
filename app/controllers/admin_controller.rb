require Rails.root.join("lib/twilio_lib")

class AdminController < ApplicationController
  USER_NAME, PASSWORD = "impact", "%76BZs2TPvWe=nqz"
  before_filter :authenticate

  rescue_from 'Enterprise::UpgradeError' do |exception|
    flash[:error] = [exception.message]
    redirect_to :back
  end

  def state
    @logged_in_campaigns = Campaign.where("id in (select distinct campaign_id from caller_sessions where on_call = 1 )")
    @logged_in_callers_count = CallerSession.on_call.count
    @errors=""
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
    if account.abandonment == "variable"
      account.update_attributes(abandonment: "fixed")
    else
      account.update_attributes(abandonment: "variable")
    end
    redirect_to :back
  end

  def index

  end

  def report
    set_report_date_range
    if request.post?
      flash.now[:notice] = ["Your #{report_type} report (#{@from_date.strftime('%m-%d-%Y')} - #{@to_date.strftime('%m-%d-%Y')}) has been added to the queue. You should receive it via email when complete."]
      Resque.enqueue(AdminReportJob, @from_date, @to_date, report_type, reports_include_undebited)
    end
  end

  def set_report_date_range
    begin
      if params[:from_date]
        @from_date= Date.strptime params[:from_date], '%m/%d/%Y'
        @to_date= Date.strptime params[:to_date], '%m/%d/%Y'
      else
        @from_date = 1.month.ago
        @to_date = DateTime.now
      end
    rescue
      #just use the defaults below
    end

    @from_date = 1.month.ago if @from_date==nil
    @to_date = DateTime.now if @to_date==nil

  end

  def users
    if params[:query]
      users=User.arel_table
      account = Account.arel_table
      @accounts = Account.includes(:users).where(users[:email].matches("%#{params[:query]}%").or(account[:id].eq(params[:query]))).paginate :page => params[:page]
    else
      @accounts = Account.includes(:users).paginate :page => params[:page]
    end
  end

  def toggle_enterprise_trial
    account      = Account.find(params[:id])
    subscription = account.billing_subscription
    quota        = account.quota

    if subscription.enterprise?
      ActiveRecord::Base.transaction do
        subscription.destroy
        quota.destroy
        account.setup_trial!
      end
      msg = 'downgraded to Trial'
    else
      customer_id     = account.billing_provider_customer_id
      payment_gateway = Billing::PaymentGateway.new(customer_id)

      payment_gateway.cancel_subscription
      ActiveRecord::Base.transaction do
        subscription.plan_changed!('enterprise')
        quota.plan_cancelled!
        quota.plan_changed!('enterprise')
      end
      msg = 'upgraded to Enterprise'
    end
    redirect_to :back, notice: ["Account##{account.id} successfully #{msg}."]
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
