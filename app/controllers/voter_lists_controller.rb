require 'tempfile'
require Rails.root.join("jobs/voter_list_upload_job")

class VoterListsController < ClientController
  layout 'v2'
  # before_filter  :setup_based_on_type
  before_filter :check_file_uploaded, :only => [:import]
  skip_before_filter :check_paid
  
  respond_to :html
  respond_to :json, :only => [:index, :create, :show, :update, :destroy]
  
  def index
    campaign = account.campaigns.find_by_id(params[:campaign_id])
    respond_with campaign.voter_lists    
  end
  
  def show
    campaign = account.campaigns.find_by_id(params[:campaign_id])
    respond_with campaign.voter_lists.find_by_id(params[:id])
  end
  
  def enable
    campaign = account.campaigns.find_by_id(params[:campaign_id])
    voter_list_ids = params[:voter_list_ids] || []
    voter_list_ids.each { |id| VoterList.enable_voter_list(id)}
  end
  
  def disable
    campaign = account.campaigns.find_by_id(params[:campaign_id])
    voter_list_ids = params[:voter_list_ids] || []
    voter_list_ids.each { |id| VoterList.disable_voter_list(id)}
  end
  

  def create
    upload = params[:upload].try(:[], "datafile")
    @campaign = account.campaigns.find(params[:campaign_id])
    s3path = VoterList.upload_file_to_s3(upload.read, csv_file_name(params[:name]))    
    voter_list = VoterList.new(name: params[:name], separator: params[:separator], headers: params[:headers].to_json, csv_to_system_map: params[:csv_to_system_map], 
    campaign_id: params[:campaign_id], s3path: s3path, account_id: account.id)
    if voter_list.save
      flash_message(:notice,I18n.t(:voter_list_upload_scheduled)) 
      Resque.enqueue(VoterListUploadJob, voter_list.id, "impactdialing", current_user.email,"")      
    end
    respond_with(voter_list, location:  edit_client_campaign_path(@campaign.id))  
    
  end
  
  def column_mapping
    @campaign = Campaign.find(params[:campaign_id])
    @csv_column_headers = params[:headers]
    @first_data_row = params[:first_data_row]
    render layout: false
  end
  
  private
  
  def csv_file_name(name)
    "#{name}_#{Time.now.to_i}_#{rand(999)}"
  end
  

  def setup_based_on_type
    if @campaign.robo?
      @layout = 'v2'
      @campaign_path = campaign_path(@campaign)
    else
      @layout = 'client'
      @campaign_path = client_campaign_path(@campaign)
    end
  end
end
