require 'ostruct'
require 'aws/s3'


class VoterList < ActiveRecord::Base
  belongs_to :campaign
  belongs_to :account
  has_many :voters, :conditions => {:active => true}
  attr_accessible :name, :separator, :headers, :s3path, :csv_to_system_map, :campaign_id, :account_id, :uploaded_file_name, :enabled

  validates_presence_of :name, :s3path, :csv_to_system_map, :uploaded_file_name
  validates_length_of :name, :minimum => 3
  validates_uniqueness_of :name, :case_sensitive => false, :scope => :account_id, :message => "for this list is already taken."
  validate :validates_file_type, :on => :create
  scope :active, where(:active => true)
  scope :by_ids, lambda { |ids| {:conditions => {:id => ids}} }
  after_save :enable_disable_voters

  VOTER_DATA_COLUMNS = {"Phone"=> "Phone", "CustomID" => "ID", "LastName"=>"LastName", "FirstName"=>"FirstName",
                        "MiddleName"=>"MiddleName", "Suffix"=>"Suffix", "Email"=>"Email", "address"=>"Address", "city"=>"City",
                        "state"=>"State/Province", "zip_code"=>"Zip/Postal Code", "country"=>"Country"}
                      
  def enable_disable_voters
    voters.update_all(enabled: enabled)      
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
  
  
  def self.disable_all
    self.all.each do |voter_list|
      voter_list.update_attribute(:enabled, false)
      voter_list.voters.update_all(enabled: false)
    end
  end

  def self.enable_all
    self.all.each do |voter_list|
      voter_list.update_attribute(:enabled, true)
      voter_list.voters.update_all(enabled: true)
    end
  end

  def self.active_voter_list_ids(campaign_id)
    active_lists = VoterList.find_all_by_campaign_id_and_active_and_enabled(campaign_id, 1, 1)
    active_lists.collect { |x| x.id }
  end

  def import_leads(csv_to_system_map, csv_filename, separator)
    batch_upload = VoterListBatchUpload.new(self, csv_to_system_map, csv_filename, separator)
    batch_upload.import_leads
  end

  def dial
    self.voters.to_be_dialed.find_in_batches(:batch_size => 500) { |voter_group|
      voter_group.each do |voter|
        return false unless self.campaign.calls_in_progress?
        voter.dial
      end
    }
    true
  end

  def voters_remaining
    voters.to_be_dialed.size
  end


  def self.read_from_s3(file_name)
    @config = YAML::load(File.open("#{Rails.root}/config/amazon_s3.yml"))
    AWS::S3::Base.establish_connection!(
        :access_key_id     => @config["access_key_id"],
        :secret_access_key => @config["secret_access_key"]
      )
      AWS::S3::S3Object.find file_name, @config['bucket']
  end

  def self.delete_from_s3(file_name)
    @config = YAML::load(File.open("#{Rails.root}/config/amazon_s3.yml"))
    AWS::S3::Base.establish_connection!(
        :access_key_id     => @config["access_key_id"],
        :secret_access_key => @config["secret_access_key"]
      )
      AWS::S3::S3Object.delete file_name, @config['bucket']
  end

  def self.upload_file_to_s3(file, file_name)
    @config = YAML::load(File.open("#{Rails.root}/config/amazon_s3.yml"))
    AWS::S3::Base.establish_connection!(
        :access_key_id     => @config["access_key_id"],
        :secret_access_key => @config["secret_access_key"]
      )
    s3path="#{Rails.env}/uploads/voter_list/#{file_name}"
    AWS::S3::S3Object.store(s3path, file, @config['bucket'],:content_type =>"application/text", :access => :private)
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

  def self.create_csv_to_system_map(csv_headers,account)
    csv_to_system_map = {}
    csv_headers.each do |header_field|
      if Voter.new.has_attribute?(header_field)
        system_field = header_field
      end
      system_field ||=  account.custom_voter_fields.find_by_name(header_field).try(:name)
      if system_field.nil?
        csv_to_system_map[header_field] = "#{header_field}"
      else
        csv_to_system_map[header_field] = system_field
      end
    end
    return csv_to_system_map
  end

  def destroy_with_voters
    voter_ids.each_slice(1000) do |ids|
      CustomVoterFieldValue.where(voter_id: ids).delete_all
      Voter.where(id: ids).delete_all
    end
    self.destroy
  end

end
