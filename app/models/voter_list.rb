require 'ostruct'

class VoterList < ActiveRecord::Base
  belongs_to :campaign
  has_many :voters, :conditions => {:active => true}

  validates_presence_of :name
  validates_uniqueness_of :name, :scope => :user_id

  module States
    INITIAL = "initial"
    VALID = "valid"
  end
  validates_inclusion_of :state, :in => [States::INITIAL, States::VALID]

  VOTER_DATA_COLUMNS = ["Phone", "VAN ID", "LastName", "FirstName", "MiddleName", "Suffix", "Email", "DWID", "Age", "Gender"]
  def import_leads(csv_to_system_map, csv_filename, seperator)
    result      = {:messages     => [],
                   :successCount => 0,
                   :failedCount  => 0}

    voters_list = FasterCSV.parse(File.read(csv_filename), :col_sep => seperator)
    csv_headers = voters_list.delete_at(0)

    if csv_to_system_map.index("VAN ID") && csv_to_system_map.index("DWID")
      csv_to_system_map.delete(csv_to_system_map.index("VAN ID"))
    end

    csv_remap_column csv_to_system_map, "VAN ID", :to => "CustomID"
    csv_remap_column csv_to_system_map, "DWID", :to => "CustomID"
    csv_phone_column_location = csv_headers.index(csv_to_system_map.index "Phone")

    voters_list.each_with_index do |voter_info, row|
      phone_number = Voter.sanitize_phone(voter_info[csv_phone_column_location])

      lead = new_lead(phone_number)
      lead.voter_list_id = self.id
      lead.user_id       = self.user_id
      lead.campaign_id   = self.campaign_id

      csv_headers.each_with_index do |csv_column_title, column_location|
        system_column = csv_to_system_map[csv_column_title]
        lead[system_column] = voter_info[column_location] if system_column
      end

      unless lead.save
        result[:messages] << "Row #{(row+2).to_s} : #{lead.errors.full_messages.join("; ")}"
        result[:failedCount] +=1
      else
        result[:successCount] +=1
      end
    end
    result
  end

  private
  def new_lead(phone_number)
    existing_voter_entry = Voter.existing_phone(phone_number, self.id)
    if existing_voter_entry.present?
      existing_voter_entry            = existing_voter_entry.first
      existing_voter_entry.num_family += 1
      existing_voter_entry.save
      lead                            = Family.new
      lead.voter_id                   = existing_voter_entry.id
    else
      lead = Voter.new
    end
    lead
  end

  def csv_remap_column(mapping, source_field, hash)
    destination_field = hash[:to]
    index             = mapping.index source_field
    if index
      mapping[index] = destination_field
    end
  end
end