module Client
  class CallersController < ClientController
    include DeletableController
    include ApplicationHelper::TimeUtils
    skip_before_filter :check_login, :only => [:reassign_to_campaign]
    before_filter :load_campaigns, :except => [:index,:destroy,:reassign_to_campaign]

    def type_name
      'caller'
    end

    def index
      @breadcrumb="Callers"
      @callers = Caller.where(:active => true, :account_id => account.id).order(:name).paginate(:page => params[:page])
    end

    def new
      @breadcrumb=[{"Callers"=>"/client/callers"}, "Add Caller"]
      @caller = Caller.new(:is_phones_only => params[:is_phones_only])
    end

    def show
      @breadcrumb=[{"Callers"=>"/client/callers"}, "Add Caller"]
      @caller = account.callers.find_by_id(params[:id])
      @caller ||= Caller.new
      if @caller.new_record?
        flash[:error] = ["No caller found. Create a new caller?"]
        render :action => "new"
      end
    end


    def update
      @caller = account.callers.find_by_id(params[:id])
      if @caller.is_on_call? && (params[:caller][:campaign_id] != @caller.campaign.id)
        flash_message(:error, "This caller is logged in and so can't be changed to a new campaign from this screen. To reassign them to a new campaign, please use the Monitor tab.")
        render :action=>"new"
      else
        if @caller.update_attributes(params[:caller])
          flash_message(:notice, "Caller updated")
          redirect_to :action=>"index"
        else
          render :action=>"new"
        end
      end
    end

    def create
      @caller = Caller.new(params[:caller])
      @caller.account_id = account.id
      if @caller.save
        flash_message(:notice, "Caller saved")
        redirect_to :action=>"index"
      else
        render :action=>"new"
      end
    end

    def destroy
      @caller = account.callers.find_by_id(params[:id])
      if !@caller.blank?
        @caller.active = false
        @caller.save
      end
      flash_message(:notice, "Caller deleted")
      redirect_to :action=>"index"
    end
    
    def reassign_to_campaign
      caller = Caller.find_by_id(params[:id])
      caller.update_attributes(:campaign_id => params[:campaign_id])
      caller_session = caller.caller_sessions.find_by_id(params[:session_id])
      caller.reassign_to_another_campaign(caller_session)
      render :nothing => true
    end

    def usage
      @caller = Caller.find(params[:id])
      @campaigns = account.campaigns.manual.for_caller(@caller)
      @campaign = @campaigns.find_by_id(params[:campaign_id])
      set_report_date_range(@campaign)
      @time_logged_in = round_for_utilization(CallerSession.time_logged_in(@caller, @campaign, @from_date, @to_date))
      @time_on_call = round_for_utilization(CallAttempt.time_on_call(@caller, @campaign, @from_date, @to_date))
      @time_in_wrapup = round_for_utilization(CallAttempt.time_in_wrapup(@caller, @campaign, @from_date, @to_date))
      @time_onhold = round_for_utilization(CallerSession.time_logged_in(@caller, @campaign, @from_date, @to_date).to_f - CallAttempt.time_on_call(@caller, @campaign, @from_date, @to_date).to_f - CallAttempt.time_in_wrapup(@caller, @campaign, @from_date, @to_date).to_f)
      @caller_time = CallerSession.caller_time(@caller, @campaign, @from_date, @to_date)
      @lead_time = CallAttempt.lead_time(@caller, @campaign, @from_date, @to_date)
    end

    def call_details
      @caller = Caller.find(params[:id])
      @campaigns = account.campaigns.manual.for_caller(@caller)
      @campaign = @campaigns.find_by_id(params[:campaign_id]) || @caller.caller_sessions.last.try(:campaign) || @caller.campaign
      set_report_date_range(@campaign)      
      @answered_call_stats = @caller.answered_call_stats(@from_date, @to_date, @campaign)
      @questions_and_responses = @campaign.try(:questions_and_responses) || {}
    end

    private
    def load_campaigns
      @campaigns = account.campaigns.manual.active
    end
    
    def set_report_date_range(campaign)
      time_zone = ActiveSupport::TimeZone.new(campaign.try(:time_zone) || @caller.try(:campaign).try(:time_zone) || "UTC")
      begin
        from_date = Time.strptime("#{params[:from_date]} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if params[:from_date]
        to_date = Time.strptime("#{params[:to_date]} #{time_zone.formatted_offset}", "%m/%d/%Y %:z") if params[:to_date]
      rescue Exception => e
        flash_message(:error, I18n.t(:invalid_date_format))
        redirect_to :back
        return
      end                    
      if campaign.nil?
        @from_date = (from_date || CallerSession.find_by_caller_id(@caller.id,:order=>"id asc", :limit=>"1").try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day      
        @to_date = (to_date || CallerSession.find_by_caller_id(@caller.id,:order=>"id desc", :limit=>"1").try(:created_at) || Time.now).in_time_zone(time_zone).end_of_day        
      else
        @from_date = (from_date || CallerSession.find_by_campaign_id(campaign.id,:order=>"id asc", :limit=>"1").try(:created_at) || Time.now).in_time_zone(time_zone).beginning_of_day      
        @to_date = (to_date || CallerSession.find_by_campaign_id(campaign.id,:order=>"id desc", :limit=>"1").try(:created_at) || Time.now).in_time_zone(time_zone).end_of_day        
      end
    end
    
  end
end
