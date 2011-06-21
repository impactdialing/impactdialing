require 'tempfile'
class VoterListsController < ClientController
  before_filter :load_campaign
  before_filter :check_file_uploaded, :only => [:import]
  skip_before_filter :check_paid
  
  def create
    if params[:upload].blank?
      flash_message(:error, "Please click \"Choose file\" and select your list before clicking Upload.")
      redirect_to campaign_view_path(@campaign.id)
      return
    end

    uploaded_file  = params[:upload]["datafile"]
    saved_filename = write_csv_file(uploaded_file)
    save_csv_filename_to_session(saved_filename)

    @separator           = separator_from_file_extension(uploaded_file.original_filename)
    @csv_column_headers = FasterCSV.parse(uploaded_file.readline, :col_sep => @separator).first

    render "column_mapping"
  end

  def import
    @separator = params["separator"]
    @csv_column_headers = JSON.parse(params["json_csv_column_headers"])

    csv_to_system_map = CsvMapping.new(params["csv_to_system_map"])
    unless csv_to_system_map.valid?
      csv_to_system_map.errors.each {|error| flash_now(:error, error) }
      render "column_mapping"
      return
    end

    csv_filename      = session[:voters_list_upload]["filename"]
    uploaded_filename = temp_file_path(csv_filename)

    @voter_list             = VoterList.new
    @voter_list.name        = params[:voter_list_name]
    @voter_list.campaign_id = params[:campaign_id]
    @voter_list.user_id     = session[:user]
    unless @voter_list.valid?
      flash_now(:error, @voter_list.errors.full_messages.join("; "))
      render "column_mapping"
      return
    end
    @voter_list.save!

    result = @voter_list.import_leads(csv_to_system_map,
                                      uploaded_filename,
                                      @separator)
    
    File.unlink uploaded_filename
    session[:voters_list_upload] = nil
    flash_message(:notice, "Upload completed. #{result[:successCount]} out of #{result[:successCount]+result[:failedCount]} rows imported successfully.")
    redirect_to campaign_view_path(@campaign.id)
  end

  private
  def load_campaign
    @campaign = Campaign.find(params[:campaign_id])
  end

  def check_file_uploaded
    return true if session[:voters_list_upload] and session[:voters_list_upload]["filename"]
    flash_message(:error, "Please upload the file again.")
    redirect_to campaign_view_path(@campaign.id)
    false
  end

  def write_csv_file(uploaded_file)
    uploaded_file = params[:upload]["datafile"]
    csv_filename  = "#{uploaded_file.original_filename}_#{Time.now.to_i}_#{rand(999)}"
    File.open(temp_file_path(csv_filename), "w") do |f|
      f.write(uploaded_file.read)
      f.flush
    end
    uploaded_file.seek 0
    csv_filename
  end

  def save_csv_filename_to_session(csv_filename)
    session[:voters_list_upload] = {
        "filename"    => csv_filename,
        "upload_time" => Time.now}
  end

  def temp_file_path(filename)
    "#{Rails.root}/tmp/#{filename}"
  end

  def separator_from_file_extension(filename)
    (File.extname(filename).downcase.include?('.csv')) ? ',' : "\t"
  end
end
