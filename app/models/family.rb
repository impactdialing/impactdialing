class Family < ActiveRecord::Base
  belongs_to :voter, :class_name => "Voter", :foreign_key => "voter_id"
  validates_presence_of :Phone
  validates_length_of :Phone, :minimum => 10

  before_validation :sanitize_phone

  def sanitize_phone
    self.Phone = Voter.sanitize_phone(self.Phone)
  end

  def apply_attribute(attribute, value)
     self[attribute] = value if self.has_attribute? attribute
  end

  def get_attribute(attribute)
    return self[attribute] if self.has_attribute? attribute
    return unless CustomVoterField.find_by_name(attribute)
    fields = CustomVoterFieldValue.voter_fields(self,CustomVoterField.find_by_name(attribute))
    return if fields.empty?
    return fields.first.value
  end

end
