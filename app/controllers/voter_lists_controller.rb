require 'tempfile'
class VoterListsController < ClientController
  before_filter :load_campaign

  def create
    if params[:upload].blank?
      flash[:error]="You must select a file to upload"
      return
    end

    uploaded_file = params[:upload]["datafile"]
    separator     = params[:seperator]=="tab" ? "\t" : ","

    @voter_list             = VoterList.new
    @voter_list.campaign_id = params[:campaign_id]
    @voter_list.name        = params[:list_name]
    @voter_list.user_id     = session[:user]
    unless @voter_list.valid?
      flash[:error] = @voter_list.errors.full_messages
      return
    end
    @voter_list.save!

    saved_filename = write_csv_file(uploaded_file, @voter_list)
    save_csv_filename_to_session(saved_filename, separator, @voter_list)

    @system_column_headers = VoterList::VOTER_DATA_COLUMNS.zip(VoterList::VOTER_DATA_COLUMNS)
    @system_column_headers = [["Not available", nil]].concat @system_column_headers
    @csv_column_headers    = FasterCSV.parse(uploaded_file.readline, :col_sep => separator).first

    render "column_mapping"
  end

  def add_to_db
    id         = params["id"].to_i
    voter_list = VoterList.find(id)
    unless voter_list.user_id.to_i == session[:user]
      flash[:error] = "You are not authorized to edit this list"
      redirect_to new_campaign_voter_list_path(@campaign.id)
      return
    end

    csv_to_system_map = params["csv_to_system_map"]
    phone_column      = csv_to_system_map.values.map(&:upcase).index("PHONE")
    unless phone_column.present?
      flash[:error] = "Could not process upload file.  Missing column header: Phone"
      redirect_to new_campaign_voter_list_path(@campaign.id)
      return
    end

    csv_filename  = session[:voters_list_uploads][id]["filename"]
    separator     = session[:voters_list_uploads][id]["separator"]
    uploaded_file = File.open(temp_file_path(csv_filename), "r")
    
    @result       = voter_list.append_from_csv(csv_to_system_map,
                                               uploaded_file,
                                               separator)
    uploaded_file.close
    File.unlink temp_file_path(csv_filename)
    session[:voters_list_uploads].delete id
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

  def write_csv_file(uploaded_file, voter_list)
    uploaded_file = params[:upload]["datafile"]
    csv_filename  = "uploaded_list_#{voter_list.id}_#{rand(100)}"
    File.open(temp_file_path(csv_filename), "w") do |f|
      f.write(uploaded_file.read)
      f.flush
    end
    uploaded_file.seek 0
    csv_filename
  end

  def save_csv_filename_to_session(csv_filename, separator, voter_list)
    session[:voters_list_uploads]                ||= {}
    session[:voters_list_uploads][voter_list.id] = {
        "filename"    => csv_filename,
        "separator"   => separator,
        "upload_time" => Time.now}
  end

  def temp_file_path(filename)
    "#{Rails.root}/tmp/#{filename}"
  end
end
