require 'tempfile'
require Rails.root.join("jobs/voter_list_upload_job")

class VoterListsController < ClientController
  before_filter :load_and_verify_campaign
  before_filter :load_voter_list, :only=> [:show, :enable, :disable, :update]
  respond_to :html
  respond_to :json, :only => [:index, :create, :show, :update, :destroy]

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
    @voter_list.update_attributes(params[:voter_list])
    respond_with @voter_list,  location: campaign_voter_lists_path(@campaign) do |format|
      format.json { render :json => {message: "Voter List updated" }, :status => :ok } if @voter_list.errors.empty?
    end
  end

  def destroy
    render :json=> {"message"=>"This opeartion is not permitted"}, :status => :method_not_allowed
  end


  def create
    upload = params[:upload].try(:[], "datafile")
    s3path = VoterList.upload_file_to_s3(upload.try('read'), VoterList.csv_file_name(params[:voter_list][:name]))
    params[:voter_list][:s3path] = s3path
    params[:voter_list][:uploaded_file_name] = upload.try('original_filename')
    params[:voter_list][:csv_to_system_map] = params[:voter_list][:csv_to_system_map].to_json
    voter_list = @campaign.voter_lists.new(params[:voter_list].merge!({account_id: account.id}))

    respond_with(voter_list, location:  edit_client_campaign_path(@campaign.id)) do |format|
      if voter_list.save
        flash_message(:notice, I18n.t(:voter_list_upload_scheduled))
        Resque.enqueue(VoterListUploadJob, voter_list.id, current_user.email, current_user.domain ,"")
        format.json { render :json => voter_list.to_json(:only => ["id", "name", "enabled"])}
      else
        flash_message(:error, voter_list.errors.full_messages.join)
        format.html { redirect_to edit_client_campaign_path(@campaign.id)}
      end
    end

  end

  def column_mapping
    upload = params[:upload].try(:[], "datafile")
    csv = upload.read
    separator = VoterList.separator_from_file_extension(upload.original_filename)
    csv_file = CSV.new(csv, :col_sep => separator)
    @csv_column_headers = csv_file.shift.compact
    @first_data_row = csv_file.shift
    render layout: false
  end

  private


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
