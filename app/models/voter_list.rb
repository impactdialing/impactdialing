require 'ostruct'

class VoterList < ActiveRecord::Base
  belongs_to :campaign
  belongs_to :account
  has_many :voters, :conditions => {:active => true}

  validates_presence_of :name
  validates_length_of :name, :minimum => 3
  validates_uniqueness_of :name, :case_sensitive => false, :scope => :account_id, :message => "for this list is already taken."

  scope :active, where(:active => true)
  scope :by_ids, lambda { |ids| {:conditions => {:id => ids}} }

  VOTER_DATA_COLUMNS = {"Phone"=> "Phone", "ID" => "ID", "LastName"=>"LastName", "FirstName"=>"FirstName",
     "MiddleName"=>"MiddleName", "Suffix"=>"Suffix", "Email"=>"Email", "address"=>"Address","city"=>"City",
     "state"=>"State/Province","zip_code"=>"Zip/Postal Code","country"=>"Country"}

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

    result = {:successCount => 0,
              :failedCount => 0}

    voters_list = CSV.parse(File.read(csv_filename), :col_sep => separator)
    csv_headers = voters_list.delete_at(0)

    csv_to_system_map.remap_system_column! "ID", :to => "CustomID"
    csv_phone_column_location = csv_headers.index(csv_to_system_map.csv_index_for "Phone")

    voters_list.each do |voter_info|
      phone_number = Voter.sanitize_phone(voter_info[csv_phone_column_location])

      lead = Voter.create(:Phone => phone_number, :voter_list => self, :account_id => account_id, :campaign_id => campaign_id)
      unless lead
        result[:failedCount] +=1
        next
      end

      csv_headers.each_with_index do |csv_column_title, column_location|
        system_column = csv_to_system_map.system_column_for csv_column_title
        lead.apply_attribute(system_column, voter_info[column_location]) unless system_column.blank?
      end

      unless lead.save
        result[:failedCount] +=1
        puts lead.errors.full_messages
        Rails.logger.info lead.errors.full_messages
      else
        result[:successCount] +=1
      end
    end
    result
  end

  def dial
    self.voters.to_be_dialed.randomly.each do |voter|
      return false unless self.campaign.calls_in_progress?
      voter.dial
    end
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
