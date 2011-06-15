require 'tempfile'
class VoterListsController < ClientController
  before_filter :load_campaign

  def create
    if params[:upload].blank?
      flash[:error]="You must select a file to upload"
      return
    end

    uploaded_file = params[:upload]["datafile"]

    @separator         = separator_from_file_extension(uploaded_file.original_filename)
    saved_filename = write_csv_file(uploaded_file)
    save_csv_filename_to_session(saved_filename)

    @system_column_headers = VoterList::VOTER_DATA_COLUMNS.zip(VoterList::VOTER_DATA_COLUMNS)
    @system_column_headers = [["Not available", nil]].concat @system_column_headers
    @csv_column_headers    = FasterCSV.parse(uploaded_file.readline, :col_sep => @separator).first

    render "column_mapping"
  end

  def add_to_db

    separator = params["separator"]
    csv_to_system_map = params["csv_to_system_map"]
    phone_column      = csv_to_system_map.values.map(&:upcase).index("PHONE")
    unless phone_column.present?
      flash[:error] = "Could not process upload file.  Missing column header: Phone"
      redirect_to new_campaign_voter_list_path(@campaign.id)
      return
    end

    csv_filename      = session[:voters_list_upload]["filename"]
    uploaded_filename = temp_file_path(csv_filename)

    @voter_list             = VoterList.new
    @voter_list.name        = params[:voter_list_name]
    @voter_list.campaign_id = params[:campaign_id]
    @voter_list.user_id     = session[:user]
    unless @voter_list.valid?
      flash[:error] = @voter_list.errors.full_messages
      return
    end
    @voter_list.save!

    @result = @voter_list.import_leads(csv_to_system_map,
                                      uploaded_filename,
                                      separator)
    
    File.unlink uploaded_filename
    session[:voters_list_upload] = nil
    render :show
  end

  def show
  end

  def new
    @voter_list = @campaign.voter_lists.new
  end

  private
  def load_campaign
    @campaign = Campaign.find(params[:campaign_id])
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

  private
  def separator_from_file_extension(filename)
    (File.extname(filename).downcase.include?('.csv')) ? ',' : "\t"
  end
end
