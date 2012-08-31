require 'tempfile'
require Rails.root.join("jobs/voter_list_upload_job")

class VoterListsController < ClientController
  layout 'v2'
  before_filter :load_campaign, :setup_based_on_type
  before_filter :check_file_uploaded, :only => [:import]
  skip_before_filter :check_paid
  
  respond_to :html
  respond_to :json, :only => [:index, :create, :show, :update, :destroy]
  
  
  def index
    campaign = account.campaigns.find_by_id(params[:campaign_id])
    respond_with campaign.voter_lists    
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
    @temp_voter_list = TempVoterList.new(name: upload.try(:original_filename))    
    csv = upload.read
    @temp_voter_list.read_column_headers(csv)
    @temp_voter_list.upload_file_to_s3!(csv)
    
    header = File.open(csv, &:readline)
    temp_voter_list.save
    
    # if params[:upload].blank?
    #   flash_message(:error, "Please click \"Choose file\" and select your list before clicking Upload.")
    #   redirect_to @campaign_path
    #   return
    # end
    
    # upload = params[:upload]["datafile"]
    # unless VoterList.valid_file?(upload.original_filename)
    #   flash_message(:error, "Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats.")
    #   redirect_to @campaign_path
    #   return
    # end

    # @separator = VoterList.separator_from_file_extension(upload.original_filename)
    # begin
    #   @csv_column_headers = CSV.new(csv, :col_sep => @separator).shift.compact
    # rescue Exception => err
    #   flash_message(:error, I18n.t(:invalid_file_uploaded))      
    #   redirect_to @campaign_path
    #   return
    # end    
    render "column_mapping", :layout => @layout
  end

  def import
    Resque.enqueue(VoterListUploadJob, params["separator"], params["json_csv_column_headers"], params["csv_to_system_map"], session[:voters_list_upload]["filename"], params[:voter_list_name], params[:campaign_id], account.id,current_user.domain, current_user.email,"")
    session[:voters_list_upload] = nil    ,
    flash_message(:notice,I18n.t(:voter_list_upload_scheduled))
    redirect_to @campaign_path  
  end
  
  private
  
  def load_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end

  def check_file_uploaded
    if session.try(:[], :voters_list_upload).try(:[], "filename").nil?
      flash_message(:error, "Please upload the file again.")
      redirect_to @campaign_path
      return false
    else
      return true
    end
  end

  def save_csv_filename_to_session(csv_filename)
    session[:voters_list_upload] = {
        "filename" => csv_filename,
        "upload_time" => Time.now}
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
