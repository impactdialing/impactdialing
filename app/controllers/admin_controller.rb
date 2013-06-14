require Rails.root.join("lib/twilio_lib")

class AdminController < ApplicationController
  USER_NAME, PASSWORD = "impact", "Mb<3Ad4F@2tCallz"
  before_filter :authenticate

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
      Resque.enqueue(AdminReportJob, @from_date, @to_date)
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
      @accounts = Account.includes(:users).where(users[:email].matches("%#{params[:query]}%")).paginate :page => params[:page]
    else
      @accounts = Account.includes(:users).paginate :page => params[:page]
    end

  end

  def

  def set_account_to_manual
    account = Account.find(params[:id])
    account.update_attribute(:activated, true)
    account.update_attribute(:card_verified, true)
    account.update_attribute(:subscription_name, "Manual")
    redirect_to :back
  end

  def login
    session[:user]=params[:id]
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
end
