require Rails.root.join("lib/twilio_lib")

class AdminController < ApplicationController
  USER_NAME, PASSWORD = "impact", "Mb<3Ad4F@2tCallz"
  before_filter :authenticate

  def state
    @logged_in_campaigns = Campaign.where("id in (select distinct campaign_id from caller_sessions where on_call=1)")
    @logged_in_callers_count = CallerSession.on_call.count
    @errors=""
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
    sql="select distinct c.account_id from caller_sessions ca
      join campaigns c on c.id=ca.campaign_id where
      ca.created_at > '#{@from_date.strftime("%Y-%m-%d")}'
      and ca.created_at  < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'
    "
    logger.info sql
    @accounts = ActiveRecord::Base.connection.execute(sql)

    @output=[]
    @accounts.each do |account_id|

      campaigns=Campaign.where("account_id=?",account_id).map{|c| c.id}
      if campaigns.length > 0

        sessions = CallerSession.where("campaign_id in (?) and tCaller is NOT NULL and created_at > '#{@from_date.strftime("%Y-%m-%d")}' and created_at  < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'", campaigns).sum("ceil(tDuration/60)").to_i
        calls = CallAttempt.from('call_attempts use index (index_call_attempts_on_campaign_id_created_at_status)').
          where("campaign_id in (?) and created_at > '#{@from_date.strftime("%Y-%m-%d")}' and created_at  < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'", campaigns).sum("ceil(tDuration/60)").to_i
        transfers = TransferAttempt.where("campaign_id in (?) and created_at > '#{@from_date.strftime("%Y-%m-%d")}' and created_at  < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'", campaigns).sum("ceil(tDuration/60)").to_i


        account = Account.find_by_id(account_id)
        unless account.nil?
          result={}
          result["account"]= account
          result["calls"]= calls
          result["sessions"]= sessions
          result["transfers"]= transfers
          @output<< result
        end
      end
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
    @accounts = Account.includes(:users).all
  end

  def set_account_to_manual
    account = Account.find(params[:id])
    account.update_attribute(:activated, true)
    account.update_attribute(:card_verified, true)
    account.update_attribute(:subscription_name, "Manual")
    redirect_to :back
  end

  def login
    session[:user]=params[:id]
    redirect_to :controller=>"client", :action=>"index"
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
