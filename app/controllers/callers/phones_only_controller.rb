module Callers
  class PhonesOnlyController < ApplicationController
    before_filter :check_login, :only=> [:report, :usage, :call_details]
    include TimeZoneHelper

    def check_login
       redirect_to :action =>"index" and return if session[:phones_only_caller].blank?
       begin
         Octopus.using(:read_slave1) do
           @caller = Caller.find(session[:phones_only_caller])
           @account = @caller.account
         end
       rescue
         logout
       end
     end

    def index
    end

    def login
      pin = params[:pin]
      password = params[:password]
      if pin.blank? || password.blank?
        flash_message(:error, "The pin or password you entered was incorrect. Please try again.")
        redirect_to :back
        return
      end
      caller = Account.authenticate_caller?(pin,password)
      unless caller.nil?
        session[:phones_only_caller] = caller.id
        redirect_to :action=>"report"
      else
        flash_message(:error, "The pin or password you entered was incorrect. Please try again.")
        redirect_to :action =>"index"
        return
      end

    end

    def logout
      session[:phones_only_caller]=nil
      redirect_to :action =>"index"
    end

    def report
    end

    def usage
      Octopus.using(:read_slave1) do
        campaigns = @account.campaigns.for_caller(@caller)
        @campaigns_data = Campaign.connection.execute(campaigns.select([:name, "campaigns.id"]).uniq.to_sql).to_a
        @campaign = campaigns.find_by_id(id: params[:campaign_id])
        @from_date, @to_date = set_date_range_callers(@campaign, @caller, params[:from_date], params[:to_date])
        @caller_usage = CallerUsage.new(@caller, @campaign, @from_date, @to_date)
      end
    end

    def call_details
      Octopus.using(:read_slave1) do
        campaigns = @account.campaigns.for_caller(@caller)
        @campaigns_data = Campaign.connection.execute(campaigns.select([:name, "campaigns.id"]).uniq.to_sql).to_a
        @campaign = campaigns.find_by_id(params[:campaign_id]) || @caller.caller_sessions.last.try(:campaign) || @caller.campaign
        @from_date, @to_date = set_date_range_callers(@campaign, @caller, params[:from_date], params[:to_date])
        @answered_call_stats = @caller.answered_call_stats(@from_date, @to_date, @campaign)
        @questions_and_responses = @campaign.try(:questions_and_responses) || {}
      end
    end

  end
end
