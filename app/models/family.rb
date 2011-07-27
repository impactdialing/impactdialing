class Family < ActiveRecord::Base
  belongs_to :voter, :class_name => "Voter", :foreign_key => "voter_id"
  validates_presence_of :Phone
  validates_length_of :Phone, :minimum => 10

  def before_validation
    self.Phone = Voter.sanitize_phone(self.Phone)
  end

  def apply_attribute(attribute, value)
     self[attribute] = value if self.has_attribute? attribute
  end

end
