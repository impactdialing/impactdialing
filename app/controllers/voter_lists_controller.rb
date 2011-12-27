require 'tempfile'

class VoterListsController < ClientController
  layout 'v2'

  before_filter :load_campaign, :setup_based_on_type
  before_filter :check_file_uploaded, :only => [:import]
  skip_before_filter :check_paid

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
    saved_filename = write_csv_file(csv,upload)
    save_csv_filename_to_session(saved_filename)
    @separator = separator_from_file_extension(upload.original_filename)
    @csv_column_headers = CSV.parse(upload.open.readline, :col_sep => @separator).first.compact

    render "column_mapping", :layout => @layout
  end

  def import
    Delayed::Job.enqueue VoterListJob.new(params["separator"], params["json_csv_column_headers"], params["csv_to_system_map"], 
    session[:voters_list_upload]["filename"], params[:voter_list_name], params[:campaign_id], account.id,current_user.domain, current_user.email)    
    session[:voters_list_upload] = nil    ,
    flash_message(:notice,I18n.t(:voter_list_upload_scheduled))
    redirect_to @campaign_path  
  end
  
  def insert_lead
    VoterList.find_by_name('web_form')
    lead = Voter.create(:Phone => params[:phone_number], :voter_list => self, :account_id => params[:account_id], :campaign_id => params[:campaign_id])
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

  def write_csv_file(csv,file)
    csv_filename = "#{file.original_filename}_#{Time.now.to_i}_#{rand(999)}"
    File.open(temp_file_path(csv_filename), "w") do |f|
      f.write(csv)
      f.flush
    end
    file.rewind
    csv_filename
  end
  
  def temp_file_path(filename)
    Rails.root.join('tmp', filename).to_s
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
