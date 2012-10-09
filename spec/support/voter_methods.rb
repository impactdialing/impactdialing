module VoterMethods
  extend self
  
  def get_attribute(voter, custom_field)
    if voter.has_attribute? custom_field
      voter[custom_field]
    elsif CustomVoterField.find_by_name(custom_field)
      fields = CustomVoterFieldValue.voter_fields(voter, CustomVoterField.find_by_name(custom_field))
      fields.first.value unless fields.empty?
    end
  end

end
