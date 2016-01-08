require 'tempfile'

class VoterListsController < ClientController
  before_filter :load_and_verify_campaign
  before_filter :load_voter_list, :only=> [:show, :enable, :disable, :update]
  respond_to :html
  respond_to :json, :only => [:index, :create, :show, :update, :destroy]

  if instrument_actions?
    instrument_action :index, :show, :enable, :disable, :update, :create,
                      :destroy, :column_mapping
  end

public
  def index
    respond_with(@campaign.voter_lists, :only => [:id, :name, :enabled])
  end

  def show
    respond_with(@voter_list, :only => [:id, :name, :enabled])
  end

  def enable
    @voter_list.enabled = true
    @voter_list.save
    respond_with @voter_list,  location: campaign_voter_lists_path(@campaign) do |format|
      format.json { render :json => {message: "Voter List enabled" }, :status => :ok } if @voter_list.errors.empty?
    end
  end

  def disable
    @voter_list.enabled = false
    @voter_list.save
    respond_with @voter_list,  location: campaign_voter_lists_path(@campaign) do |format|
      format.json { render :json => {message: "Voter List disabled" }, :status => :ok } if @voter_list.errors.empty?
    end
  end

  def update
    @voter_list.update_attributes(voter_list_params)
    respond_with @voter_list,  location: campaign_voter_lists_path(@campaign) do |format|
      format.json { render :json => {message: "Voter List updated" }, :status => :ok } if @voter_list.errors.empty?
    end
  end

  def destroy
    render :json=> {"message"=>"This operation is not permitted"}, :status => :method_not_allowed
  end

  def create
    call_list = CallList::Upload.new(@campaign, :voter_list,
                                      params[:upload], voter_list_params)
    call_list.save
    voter_list = call_list.child_instance

    respond_with(voter_list, location: edit_client_campaign_path(@campaign.id)) do |format|
      if voter_list.save
        voter_list.queue_upload_processor(current_user.email)

        url = edit_client_script_path(@campaign.script_id)
        flash_message(:notice, I18n.t(:voter_list_upload_scheduled, url: url).html_safe)

        # API
        format.json do
          render({
            json: voter_list.to_json({
              only: [:id, :name, :enabled, :skip_wireless, :campaign_id, :purpose]
            })
          })
        end
      else
        format.html {
          flash_message(:error, voter_list.errors.full_messages.join)
          redirect_to edit_client_campaign_path(@campaign.id)
        }
      end
    end
  end

  def column_mapping
    upload          = params[:upload].try(:[], "datafile")
    csv             = upload.read
    separator       = VoterList.separator_from_file_extension(upload.original_filename)
    @csv_validator  = CsvValidator.new(csv, separator)
    @use_custom_ids = @campaign.can_use_custom_ids?
    render layout: false
  end

private
  def voter_list_params
    params.require(:voter_list).
      permit(
        :name, :s3path, :uploaded_file_name, :account_id, :purpose,
        :upload, :campaign_id, :headers, :separator, :skip_wireless,
        csv_to_system_map: params[:voter_list][:csv_to_system_map].try(:keys)
      )
  end

  def load_voter_list
    begin
      @voter_list = @campaign.voter_lists.find(params[:id])
    rescue ActiveRecord::RecordNotFound => e
      render :json=> {"message"=>"Resource not found"}, :status => :not_found
      return
    end
  end

  def load_and_verify_campaign
    begin
      @campaign = Campaign.find(params[:campaign_id])
    rescue ActiveRecord::RecordNotFound => e
      render :json=> {"message"=>"Resource not found"}, :status => :not_found
      return
    end
    if @campaign.account != account
      render :json => {message: 'Cannot access campaign.'}, :status => :unauthorized
      return
    end
  end

  def setup_based_on_type
    @campaign_path = client_campaign_path(@campaign)
  end
end
