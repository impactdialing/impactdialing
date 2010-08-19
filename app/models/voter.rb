class Voter < ActiveRecord::Base
  #  validates_uniqueness_of :Phone, :scope => [:campaign_id, :active] :message => " is already entered in this campaign"
  validate :unique_number
  belongs_to :voter_list, :class_name => "VoterList", :foreign_key => "voter_list_id"
 
 def unique_number
   if new_record?
     errors.add("Phone is already entered in this campaign and") if Voter.find_by_Phone(self.Phone, :conditions=>"active=1 and campaign_id=#{self.campaign_id}")
   else
     errors.add("Phone is already entered in this campaign and") if Voter.find_by_Phone(self.Phone, :conditions=>"active=1 and campaign_id=#{self.campaign_id} and id <> #{self.id}")
   end
     
 end
 
  def before_validation
    #clean u phone
     self.Phone = self.Phone.gsub(/[^0-9]/, "") unless self.Phone.blank?
  end

  cattr_reader :per_page
  @@per_page = 25
  
  def self.upload_headers
    ["Phone","ID","LastName","FirstName","MiddleName","Suffix","Email"]
  end

  def self.upload_fields
    ["Phone","CustomID","LastName","FirstName","MiddleName","Suffix","Email"]
  end

end
