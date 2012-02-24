module Client
  class CallersController < ClientController
    include DeletableController
    skip_before_filter :check_login, :only => [:reassign_to_campaign]
    before_filter :load_campaigns, :except => [:index,:destroy,:reassign_to_campaign]
    before_filter :set_report_date_range, :only => [:usage, :call_details]

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
    end

    def call_details
      @caller = Caller.find(params[:id])
      @campaigns = account.campaigns.manual.for_caller(@caller)
      @campaign = @campaigns.find_by_id(params[:campaign_id]) || @caller.caller_sessions.first.try(:campaign)
      @questions_and_responses = @campaign.try(:questions_and_responses) || {}
    end

    private
    def load_campaigns
      @campaigns = account.campaigns.manual.active
    end
  end
end
