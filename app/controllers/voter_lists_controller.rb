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
    csv = upload.read
    saved_filename = write_csv_file(csv,upload)
    save_csv_filename_to_session(saved_filename)
    @separator = separator_from_file_extension(upload.original_filename)
    @csv_column_headers = CSV.parse(upload.open.readline, :col_sep => @separator).first.compact

    render "column_mapping", :layout => @layout
  end

  def import
    @separator = params["separator"]
    @csv_column_headers = JSON.parse(params["json_csv_column_headers"])

    csv_to_system_map = CsvMapping.new(params["csv_to_system_map"])
    unless csv_to_system_map.valid?
      csv_to_system_map.errors.each { |error| flash_now(:error, error) }
      render "column_mapping", :layout => @layout
      return
    end

    csv_filename = session[:voters_list_upload]["filename"]
    uploaded_filename = temp_file_path(csv_filename)

    @voter_list = VoterList.new
    @voter_list.name = params[:voter_list_name]
    @voter_list.campaign_id = params[:campaign_id]
    @voter_list.account_id = account.id
    unless @voter_list.valid?
      flash_now(:error, @voter_list.errors.full_messages.join("; "))
      render "column_mapping", :layout => @layout
      return
    end
    @voter_list.save!

    begin
      result = @voter_list.import_leads(csv_to_system_map,
                                        uploaded_filename,
                                        @separator)
      flash_message(:notice, "Upload completed. #{result[:successCount]} out of #{result[:successCount]+result[:failedCount]} rows imported successfully.")
    rescue CSV::MalformedCSVError => err
      @voter_list.destroy
      flash_message(:error, "Invalid CSV file. Could not import.")
    ensure
      File.unlink uploaded_filename
      session[:voters_list_upload] = nil
    end

    redirect_to @campaign_path
  end

  private
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

  def save_csv_filename_to_session(csv_filename)
    session[:voters_list_upload] = {
        "filename" => csv_filename,
        "upload_time" => Time.now}
  end

  def temp_file_path(filename)
    Rails.root.join('tmp', filename).to_s
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
