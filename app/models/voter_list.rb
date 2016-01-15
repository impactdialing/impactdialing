require 'ostruct'
require 'windozer'

class VoterList < ActiveRecord::Base
  serialize :csv_to_system_map, JSON
  
  belongs_to :campaign
  belongs_to :account
  has_many :voters, -> { where active: true }
  has_many :households

  scope :disabled, -> { where enabled: false }
  
  validates_presence_of :name, :s3path, :csv_to_system_map, :uploaded_file_name
  validates_length_of :name, :minimum => 3
  validates_uniqueness_of :name, :case_sensitive => false, :scope => :account_id, :message => "for this list is already taken."
  validate :validates_file_type, :on => :create
  validate :custom_id_usage, :before => :validation
  validate :csv_mapping_rules, :on => :create

  before_create :transcode_csv_to_system_map
  
  after_update :enable_disable_members

  VOTER_DATA_COLUMNS = {"phone"=> "Phone", "custom_id" => "ID", "last_name"=>"LastName", "first_name"=>"FirstName",
                        "middle_name"=>"MiddleName", "suffix"=>"Suffix", "email"=>"Email", "address"=>"Address", "city"=>"City",
                        "state"=>"State/Province", "zip_code"=>"Zip/Postal Code", "country"=>"Country"}
  BLANK_HEADER = '<Blank header>'

private
  def log(level, msg)
    msg = "VoterList: #{msg}"
    logger.send(level, msg)
  end

  def transcode_csv_to_system_map
    transcoded = {}
    csv_to_system_map.each do |header,prop|
      header = Windozer::String.bom_away(header)
      transcoded[header] = prop
    end
    self.csv_to_system_map = transcoded
  end

  def custom_id_usage
    send("custom_id_usage_#{purpose}")
  end

  def csv_mapping_rules
    send("csv_mapping_#{purpose}")
  end

  def custom_id_usage_import
    if campaign.can_use_custom_ids?
      if campaign.requires_custom_ids? and (not self.maps_custom_id?)
        errors.add(:csv_to_system_map, I18n.t('activerecord.errors.models.voter_list.custom_id_map_required'))
      end
    elsif campaign.cannot_use_custom_ids? and self.maps_custom_id?
      errors.add(:csv_to_system_map, I18n.t('activerecord.errors.models.voter_list.custom_id_map_prohibited'))
    end
  end

  def custom_id_usage_prune_numbers
    return true
  end

  def custom_id_usage_prune_leads
    log :debug, "custom_id_usage_prune_leads: maps_custom_id?(#{maps_custom_id?}) campaign.using?(#{campaign.cannot_use_custom_ids?})"
    if (not maps_custom_id?) or campaign.cannot_use_custom_ids?
      errors.add(:csv_to_system_map, I18n.t('activerecord.errors.models.voter_list.custom_id_map_required'))
    end
  end

  def csv_mapping
    @csv_mapping ||= CsvMapping.new(csv_to_system_map)
  end

  def csv_mapping_import
    unless csv_mapping.valid?
      csv_mapping.errors.each do |msg|
        errors.add(:csv_to_system_map, msg)
      end
    end
  end

  def csv_mapping_prune_numbers
    csv_mapping_import
  end

  def csv_mapping_prune_leads
    true
  end

  ##
  # Useful for after_create hook.
  # Not in-use yet; CustomVoterFields are created via CallList::Imports#create_new_custom_voter_fields!
  def save_custom_fields
    new_fields = []
    csv_to_system_map.each do |key,value|
      next if VOTER_DATA_COLUMNS.keys.include?(value)
      new_fields << value
    end
    unless new_fields.empty?
      contact_fields_options.save(new_fields)
    end
  end

public

  def self.upload_clean_file_to_s3(file, file_name)
    s3path="#{Rails.env}/uploads/voter_list/#{file_name}"
    return s3path if file.nil?
    clean_file = Windozer.to_unix( file )
    AmazonS3.new.write(s3path, clean_file)
    s3path
  end

  def self.csv_file_name(list_name)
    "#{list_name}_#{Time.now.to_i}_#{rand(999)}"
  end

  def self.valid_file?(filename)
    return false if filename.nil?
    ['.csv','.txt'].include? File.extname(filename).downcase
  end

  def self.separator_from_file_extension(filename)
    (File.extname(filename).downcase.include?('.csv')) ? ',' : "\t"
  end

  def self.read_from_s3(file_name)
    Windozer.to_unix( AmazonS3.new.read(file_name) )
  end

  def self.delete_from_s3(file_name)
    AmazonS3.new.delete(file_name)
  end

  def upload_processors
    HashWithIndifferentAccess.new({
      import: [CallList::Jobs::Import, id],
      prune_numbers: [CallList::Jobs::Prune, id, 'numbers'],
      prune_leads: [CallList::Jobs::Prune, id, 'leads']
    })
  end

  def queue_upload_processor(email)
    return if new_record?

    job = upload_processors[purpose]
    Resque.enqueue(job.shift, *job, email) if job
  end

  def stats
    @stats ||= CallList::Stats.new(self)
  end

  def contact_fields_options
    @contact_fields ||= CallFlow::Web::ContactFields::Options.new(self.account)
  end

  def maps_custom_id?
    csv_to_system_map.values.include? 'custom_id'
  end

  def read_from_s3
    self.class.read_from_s3(s3path)
  end

  def enable_disable_members
    Resque.enqueue(CallList::Jobs::ToggleActive, self.id)
  end

  def validates_file_type
    if uploaded_file_name.nil?
      errors.add(:base, "Please upload a file.")
      return
    end

    if ['.csv','.txt'].include? File.extname(uploaded_file_name).downcase
    else
      errors.add(:base, "Wrong file format. Please upload a comma-separated value (CSV) or tab-delimited text (TXT) file. If your list is in Excel format (XLS or XLSX), use \"Save As\" to change it to one of these formats.")
    end
  end
end

# ## Schema Information
#
# Table name: `voter_lists`
#
# ### Columns
#
# Name                      | Type               | Attributes
# ------------------------- | ------------------ | ---------------------------
# **`id`**                  | `integer`          | `not null, primary key`
# **`name`**                | `string(255)`      |
# **`account_id`**          | `integer`          |
# **`active`**              | `boolean`          | `default(TRUE)`
# **`created_at`**          | `datetime`         |
# **`updated_at`**          | `datetime`         |
# **`campaign_id`**         | `integer`          |
# **`enabled`**             | `boolean`          | `default(TRUE)`
# **`separator`**           | `string(255)`      |
# **`headers`**             | `text`             |
# **`csv_to_system_map`**   | `text`             |
# **`s3path`**              | `text`             |
# **`uploaded_file_name`**  | `string(255)`      |
# **`voters_count`**        | `integer`          | `default(0)`
# **`skip_wireless`**       | `boolean`          | `default(TRUE)`
# **`households_count`**    | `integer`          |
# **`purpose`**             | `string(255)`      | `default("import")`
#
# ### Indexes
#
# * `index_voter_lists_on_user_id_and_name` (_unique_):
#     * **`account_id`**
#     * **`name`**
#
