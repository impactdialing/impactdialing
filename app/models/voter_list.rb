require 'ostruct'

class VoterList < ActiveRecord::Base
  belongs_to :campaign
  has_many :voters, :conditions => {:active => true}

  validates_presence_of :name
  validates_length_of :name, :minimum => 3
  validates_uniqueness_of :name, :scope => :user_id, :message => "for this voter list is already taken"

  named_scope :by_ids, lambda {|ids| {:conditions => {:id => ids} } }
  
  VOTER_DATA_COLUMNS = ["Phone", "ID", "LastName", "FirstName", "MiddleName", "Suffix", "Email", "Age", "Gender"]

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

  def import_leads(csv_to_system_map, csv_filename, separator)

    result      = {:successCount => 0,
                   :failedCount  => 0}

    voters_list = FasterCSV.parse(File.read(csv_filename), :col_sep => separator)
    csv_headers = voters_list.delete_at(0)

    csv_to_system_map.remap_system_column! "ID", :to => "CustomID"
    csv_phone_column_location = csv_headers.index(csv_to_system_map.csv_index_for "Phone")

    voters_list.each_with_index do |voter_info, row|
      phone_number = Voter.sanitize_phone(voter_info[csv_phone_column_location])

      lead = new_lead(phone_number)
      unless lead
        result[:failedCount] +=1
        next
      end
      
      lead.voter_list_id = self.id
      lead.user_id       = self.user_id
      lead.campaign_id   = self.campaign_id

      csv_headers.each_with_index do |csv_column_title, column_location|
        system_column = csv_to_system_map.system_column_for csv_column_title
        lead[system_column] = voter_info[column_location] if system_column
      end

      unless lead.save
        result[:failedCount] +=1
      else
        result[:successCount] +=1
      end
    end
    result
  end

  def dial
    self.voters.each { |voter| voter.dial}
  end

  private
  def new_lead(phone_number)
    existing_voter_entry = Voter.existing_phone_in_campaign(phone_number, self.campaign_id)
    if existing_voter_entry.present?
      if existing_voter_entry.detect {|entry| entry.voter_list_id == self.id}
        existing_voter_entry            = existing_voter_entry.first
        existing_voter_entry.num_family += 1
        existing_voter_entry.save
        lead                            = Family.new
        lead.voter_id                   = existing_voter_entry.id
      else
        return nil
      end
    else
      lead = Voter.new
    end
    lead
  end
end