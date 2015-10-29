module Client
  class CampaignsController < ClientController
    before_filter :check_admin_only
    before_filter :load_and_verify_campaign, :except => [:index, :new, :create, :archived]
    respond_to :html, :json

    if instrument_actions?
      instrument_action :index, :new, :edit, :create, :update, :destroy, :archived, :can_change_script
    end

    def index
      @campaigns     = account.campaigns.active.paginate :page => params[:page]
      @caller_counts = account.callers.active.where(campaign_id: @campaigns.pluck(:id)).group(:campaign_id).count
      respond_with @campaigns
    end

    def new
      @campaign = account.campaigns.new(type: Campaign::Type::POWER,
                                        time_zone: "Pacific Time (US & Canada)",
                                        start_time: Time.parse("9am"),
                                        end_time: Time.parse("9pm"),
                                        acceptable_abandon_rate: 0.03)
      load_scripts
      # new_list
      respond_with @campaign
    end


    def show
      respond_with @campaign do |format|
        format.html {redirect_to edit_client_campaign_path(@campaign)}
      end
    end

    def edit
      load_scripts
      new_list

      respond_with @campaign
    end

    def create
      @campaign = account.campaigns.new
      save_campaign
      respond_with @campaign, location: client_campaigns_path
    end


    def update
      save_campaign
      respond_with @campaign,  location: client_campaigns_url do |format|
        format.json { render :json => {message: "Campaign updated" }, :status => :ok } if @campaign.errors.empty?
      end
    end

    def destroy
      @campaign.active = false
      @campaign.save ?  flash_message(:notice, "Campaign archived") : flash_message(:error, @campaign.errors.full_messages.join)
      respond_with @campaign,  location: client_campaigns_url do |format|
        format.json { render :json => {message: "Campaign archived" }, :status => :ok } if @campaign.errors.empty?
      end
    end

    def archived
      @campaigns = Campaign.deleted.for_account(@user.account).paginate(:page => params[:page], :order => 'id desc')
      @download_report_count = DownloadedReport.accounts_active_report_count(@campaigns.collect{|c| c.id}, session[:internal_admin])
      respond_with @campaigns do |format|
        format.html { render :archived }
        format.json { render :json => @campaigns.to_json }
      end
    end

    def can_change_script
      if (@campaign.script_id.to_s == params[:script_id] || params[:script_id].nil?)
          render :json => {message: true, script_id: @campaign.script_id}
      else
          render :json => {message: @campaign.script.answers_recorded?, script_id: @campaign.script_id}
      end
    end


    private

    def load_and_verify_campaign
      begin
        @campaign = Campaign.includes(:list_activities).find(params[:id] || params[:campaign_id])
      rescue ActiveRecord::RecordNotFound => e
        render :json=> {"message"=>"Resource not found"}, :status => :not_found
        return
      end
      if @campaign.account != account
        render :json => {message: 'Cannot access campaign.'}, :status => :unauthorized
        return
      end
    end

    def load_scripts
      @scripts = account.scripts.active
    end

    def new_list
      @voter_list = @campaign.voter_lists.new
    end

    def save_campaign
      load_scripts
      flash_message(:notice, "Campaign saved") if @campaign.update_attributes(campaign_params)
    end

    def campaign_params
      params.require(:campaign).permit(
        :name, :script_id, :caller_id, :type, :recording_id, :use_recordings,
        :recycle_rate, :answering_machine_detect, :start_time, :end_time,
        :time_zone, :acceptable_abandon_rate, :call_back_after_voicemail_delivery,
        :caller_can_drop_message_manually, voter_lists_attributes: [:id, :enabled]
      )
    end
  end
end
