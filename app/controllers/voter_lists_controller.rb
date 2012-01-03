require 'tempfile'

class VoterListsController < ClientController
  layout 'v2'

  before_filter :load_campaign, :setup_based_on_type
  before_filter :check_file_uploaded, :only => [:import]
  skip_before_filter :check_paid
  before_filter :check_login, :except => [:insert_lead]

  def create

    if params[:upload].blank?
      flash_message(:error, "Please click \"Choose file\" and select your list before clicking Upload.")
      redirect_to @campaign_path
      return
    end
    upload = params[:upload]["datafile"]
    unless valid_file?(upload.original_filename)
      flash_message(:error, "Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats.")
      redirect_to @campaign_path
      return
    end

    
    csv = upload.read
    csv_filename = "#{upload.original_filename}_#{Time.now.to_i}_#{rand(999)}"
    saved_file_name = VoterList.upload_file_to_s3(csv, csv_filename)
    save_csv_filename_to_session(saved_file_name)
    @separator = separator_from_file_extension(upload.original_filename)
    @csv_column_headers = CSV.parse(upload.open.readline, :col_sep => @separator).first.compact
    render "column_mapping", :layout => @layout
  end

  def import
    if Rails.env == 'heroku' || 'heroku_staging'
      job = VoterListJob.new(params["separator"], params["json_csv_column_headers"], params["csv_to_system_map"], 
      session[:voters_list_upload]["filename"], params[:voter_list_name], params[:campaign_id], account.id,current_user.domain, current_user.email)    
      session[:voters_list_upload] = nil    ,
      flash_message(:notice,I18n.t(:voter_list_upload_scheduled))
      job.perform
    else
      Delayed::Job.enqueue VoterListJob.new(params["separator"], params["json_csv_column_headers"], params["csv_to_system_map"], 
      session[:voters_list_upload]["filename"], params[:voter_list_name], params[:campaign_id], account.id,current_user.domain, current_user.email)    
      session[:voters_list_upload] = nil    ,
      flash_message(:notice,I18n.t(:voter_list_upload_scheduled))
    end
    redirect_to @campaign_path  
  end
  
  def insert_lead
    voter_list = VoterList.find_by_name_and_campaign_id('web_form',params[:campaign_id])
    if voter_list.nil?
      voter_list =  VoterList.create(name: 'web_form', account_id: params[:account_id], active: true, campaign_id: params[:campaign_id], enabled: true)
    end
    
    lead  =  Voter.create!(:Phone => params[:phone_number], :voter_list => voter_list, 
    :account_id => params[:account_id], :campaign_id => params[:campaign_id], CustomID: params[:custom_id],
    FirstName: params[:first_name], LastName: params[:last_name], MiddleName: params[:middle_name], Email: params[:email], address: params[:address],
     city: params[:city], state: params[:state], zip_code: params[:zip_code], country: params[:country], priority: "1")        
     
    render nothing: true 
  end
  
  

  private
  def valid_file?(filename)
    ['.csv','.txt'].include? File.extname(filename).downcase
  end
  
  def load_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end

  def check_file_uploaded
    return true if session[:voters_list_upload] and session[:voters_list_upload]["filename"]
    flash_message(:error, "Please upload the file again.")
    redirect_to @campaign_path
    false
  end

  
  

  def save_csv_filename_to_session(csv_filename)
    session[:voters_list_upload] = {
        "filename" => csv_filename,
        "upload_time" => Time.now}
  end


  def separator_from_file_extension(filename)
    (File.extname(filename).downcase.include?('.csv')) ? ',' : "\t"
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
