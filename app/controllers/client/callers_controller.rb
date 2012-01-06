module Client
  class CallersController < ClientController
    include DeletableController
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
    end

    def update
      @caller = account.callers.find_by_id(params[:id])
      if @caller.update_attributes(params[:caller])
        flash_message(:notice, "Caller updated")
        redirect_to :action=>"index"
      else
        render :action=>"new"
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
      reassign_caller_session_to_campaign if (!caller.is_phones_only? && caller_session.attempt_in_progress.nil?)
      render :nothing => true
    end
    
    private
    def load_campaigns
      @campaigns = account.campaigns.manual.active
    end
  end
end
