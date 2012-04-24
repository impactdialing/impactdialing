require Rails.root.join("lib/twilio_lib")

class AdminController < ApplicationController
  USER_NAME, PASSWORD = "impact", "Mb<3Ad4F@2tCallz"
  before_filter :authenticate


  def state
    @logged_in_campaigns = Campaign.all(:conditions=>"id in (select distinct campaign_id from caller_sessions where on_call=1)")
    @logged_in_callers = CallerSession.find_all_by_on_call(1)
    @errors=""
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
      robo_campaigns=Campaign.where("account_id=? and robo=1",account_id).map{|c| c.id}
      if campaigns.length > 0
        
        sessions = CallerSession.where("campaign_id in (?) and tCaller is NOT NULL and created_at > '#{@from_date.strftime("%Y-%m-%d")}' and created_at  < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'", campaigns).sum("ceil(tDuration/60)").to_i
        calls = CallAttempt.where("campaign_id in (?) and created_at > '#{@from_date.strftime("%Y-%m-%d")}' and created_at  < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'", campaigns).sum("ceil(tDuration/60)").to_i
        if robo_campaigns.length > 0
          broadcast = CallAttempt.where("campaign_id in (?) and created_at > '#{@from_date.strftime("%Y-%m-%d")}' and created_at  < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'", robo_campaigns).sum("ceil(tDuration/60)").to_i
        else
          broadcast=0
        end
        transfers = TransferAttempt.where("campaign_id in (?) and created_at > '#{@from_date.strftime("%Y-%m-%d")}' and created_at  < '#{(@to_date+1.day).strftime("%Y-%m-%d")}'", campaigns).sum("ceil(tDuration/60)").to_i

        result={}
        result["account"]=Account.find(account_id).first
        result["calls"]=calls
        result["broadcast"]=broadcast
        result["sessions"]=sessions
        result["transfers"]=transfers
        @output<< result

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
    @accounts = Account.all
  end

  def toggle_activated
    account = Account.find(params[:id])
    account.update_attribute(:activated, !account.activated)
    redirect_to :back
  end

  def toggle_card_verified
    account = Account.find(params[:id])
    account.update_attribute(:card_verified, !account.card_verified)
    redirect_to :back
  end

  def login
    session[:user]=params[:id]
    redirect_to :controller=>"client", :action=>"index"
  end
  
  def destroy
    @account = Account.find(params[:id])
    @account.users.try(:each){|user| user.destroy }
    @account.destroy
    redirect_to :back
  end

  def robo_log_parse
    counter = 1
    out=[]
    f = File.new(Rails.root.join('result_combined.txt'))
    while (line = f.gets)
      hash = eval(line.gsub("Parameters:", "").strip)
      out << hash["attempt"]
      counter = counter + 1
    end
    render :text=>out.join(",")
  end

  def charge
    @account = Account.find(params[:id])
    @billing_account = @account.billing_account
    @emails = @account.users.map(&:email).join(', ')
    if @billing_account.nil?
      render :text => "User has not entered credit card info"
      return
    end
    if request.post?
      @success = charge_account(@billing_account, params[:tocharge].to_f)
    end
  end

  def charge_account(billing_account, amount)
    creditcard = ActiveMerchant::Billing::CreditCard.new(
        :number => billing_account.decrypt_cc,
        :month => billing_account.expires_month,
        :year => billing_account.expires_year,
        :type => billing_account.cardtype,
        :first_name => billing_account.first_name,
        :last_name => billing_account.last_name
    )

    user = billing_account.account.users.first
    billing_address = {
        :name => "#{user.fname} #{user.lname}",
        :address1 => billing_account.address1,
        :zip => billing_account.zip,
        :city => billing_account.city,
        :state => billing_account.state,
        :country => 'US'
    }
    options = {:address => {}, :address1 => billing_address, :billing_address => billing_address, :ip=>"127.0.0.1", :order_id=>""}
    @response = BILLING_GW.authorize(amount.to_f*100, creditcard, options)

    if @response.message == 'APPROVED'
      BILLING_GW.capture(@amount, @response.authorization)
      true
    else
      false
    end

  end

  def log
    if params[:id]
      @reqs=Dump.find_all_by_guid(params[:id], :order=>"first_line")
      @session=0
      @reqs.each do |r|
        begin
          p=YAML.load(r.params)
          @session=p[:session] if p[:session]!=nil
        rescue
        end
      end
      @attempts = CallAttempt.find_all_by_caller_session_id(@session, :order=>"id")
    end
  end

  private
  def authenticate
    authenticate_or_request_with_http_basic(self.class.controller_path) do |user_name, password|
      user_name == USER_NAME && password == PASSWORD
    end
  end
end
