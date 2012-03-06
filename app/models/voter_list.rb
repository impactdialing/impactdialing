require 'ostruct'
require 'aws/s3'


class VoterList < ActiveRecord::Base
  belongs_to :campaign
  belongs_to :account
  has_many :voters, :conditions => {:active => true}

  validates_presence_of :name
  validates_length_of :name, :minimum => 3
  validates_uniqueness_of :name, :case_sensitive => false, :scope => :account_id, :message => "for this list is already taken."

  scope :active, where(:active => true)
  scope :by_ids, lambda { |ids| {:conditions => {:id => ids}} }

  VOTER_DATA_COLUMNS = {"Phone"=> "Phone", "CustomID" => "ID", "LastName"=>"LastName", "FirstName"=>"FirstName",
                        "MiddleName"=>"MiddleName", "Suffix"=>"Suffix", "Email"=>"Email", "address"=>"Address", "city"=>"City",
                        "state"=>"State/Province", "zip_code"=>"Zip/Postal Code", "country"=>"Country"}

  def self.disable_all
    self.all.each do |voter_list|
      voter_list.update_attribute(:enabled, false)
    end
  end

  def self.enable_all
    self.all.each do |voter_list|
      voter_list.update_attribute(:enabled, true)
    end
  end

  def self.active_voter_list_ids(campaign_id)
    active_lists = VoterList.find_all_by_campaign_id_and_active_and_enabled(campaign_id, 1, 1)
    active_lists.collect { |x| x.id }
  end

  def import_leads(csv_to_system_map, csv_filename, separator)    
    batch_upload = VoterListBatchUpload.new(self)
    batch_upload.import_leads(csv_to_system_map, csv_filename, separator)
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

  def self.enable_voter_list(id)
    voter_list = VoterList.find(id)
    voter_list.enabled = true
    voter_list.save
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
        csv_to_system_map[header_field] = "Custom #{header_field}"
      else
        csv_to_system_map[header_field] = system_field
      end
    end
    return csv_to_system_map
  end
  
  

  private
  def new_lead(phone_number)
    existing_voter_entry = Voter.existing_phone_in_campaign(phone_number, self.campaign_id)
    if existing_voter_entry.present?
      if existing_voter_entry.detect { |entry| entry.voter_list_id == self.id }
        existing_voter_entry = existing_voter_entry.first
        existing_voter_entry.num_family += 1
        existing_voter_entry.save
        lead = Family.new(:voter => existing_voter_entry, :Phone => phone_number, :voter_list_id => id, :account_id => account_id, :campaign_id => campaign_id)
      else
        return nil
      end
    else
      lead = Voter.create(:Phone => phone_number, :voter_list => self, :account_id => account_id, :campaign_id => campaign_id)
    end
    lead
  end
end
