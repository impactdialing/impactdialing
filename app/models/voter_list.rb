require 'ostruct'
class VoterList < ActiveRecord::Base
  attr_accessible :name, :separator, :headers, :s3path, :csv_to_system_map, :campaign_id, :account_id, :uploaded_file_name, :enabled, :skip_wireless

  serialize :csv_to_system_map, JSON
  
  belongs_to :campaign
  belongs_to :account
  has_many :voters, :conditions => {:active => true}
  has_many :households
  
  validates_presence_of :name, :s3path, :csv_to_system_map, :uploaded_file_name
  validates_length_of :name, :minimum => 3
  validates_uniqueness_of :name, :case_sensitive => false, :scope => :account_id, :message => "for this list is already taken."
  validate :validates_file_type, :on => :create
  
  after_update :enable_disable_members

  VOTER_DATA_COLUMNS = {"phone"=> "Phone", "custom_id" => "ID", "last_name"=>"LastName", "first_name"=>"FirstName",
                        "middle_name"=>"MiddleName", "suffix"=>"Suffix", "email"=>"Email", "address"=>"Address", "city"=>"City",
                        "state"=>"State/Province", "zip_code"=>"Zip/Postal Code", "country"=>"Country"}
  BLANK_HEADER = '<Blank header>'

  def self.upload_file_to_s3(file, file_name)
    s3path="#{Rails.env}/uploads/voter_list/#{file_name}"
    return s3path if file.nil?
    AmazonS3.new.write(s3path, file)
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
    require 'windozer'
    Windozer.to_unix( AmazonS3.new.read(file_name) )
  end

  def self.delete_from_s3(file_name)
    AmazonS3.new.delete(file_name)
  end

  def read_from_s3
    self.class.read_from_s3(s3path)
  end

  def enable_disable_members
    Resque.enqueue(VoterListChangeJob, self.id, self.enabled)
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

  # going away very soon (next release)
  # def self.disable_all
  #   deprecated_method_warning(:disable_all)
  #   self.all.each do |voter_list|
  #     voter_list.update_attribute(:enabled, false)
  #     voter_list.voters.update_all(enabled: false)
  #   end
  # end
  # def self.enable_all
  #   deprecated_method_warning(:enable_all)
  #   self.all.each do |voter_list|
  #     voter_list.update_attribute(:enabled, true)
  #     voter_list.voters.update_all(enabled: true)
  #   end
  # end
  # def self.active_voter_list_ids(campaign_id)
  #   deprecated_method_warning(:active_voter_list_ids)
  #   VoterList.where(campaign_id: campaign_id, active: 1, enabled: 1).pluck(:id)
  # end
  # def voters_remaining
  #   voters.to_be_dialed.size
  # end
  # deprecate :voters_remaining
  # def destroy_with_voters
  #   voter_ids.each_slice(1000) do |ids|
  #     CustomVoterFieldValue.where(voter_id: ids).delete_all
  #     Voter.where(id: ids).delete_all
  #   end
  #   self.destroy
  # end
  # deprecate :destroy_with_voters
  # def self.create_csv_to_system_map(csv_headers,account)
  #   ActiveSupport::Deprecation.warn('VoterList.create_csv_to_system_map is now a no-op.')
  #   return

  #   csv_to_system_map = {}
  #   csv_headers.each do |header_field|
  #     if Voter.new.has_attribute?(header_field)
  #       system_field = header_field
  #     end
  #     system_field ||=  account.custom_voter_fields.find_by_name(header_field).try(:name)
  #     if system_field.nil?
  #       csv_to_system_map[header_field] = "#{header_field}"
  #     else
  #       csv_to_system_map[header_field] = system_field
  #     end
  #   end
  #   return csv_to_system_map
  # end
  #/ going away very soon (next release)
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
# **`account_id`**          | `string(255)`      |
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
#
# ### Indexes
#
# * `index_voter_lists_on_user_id_and_name` (_unique_):
#     * **`account_id`**
#     * **`name`**
#
